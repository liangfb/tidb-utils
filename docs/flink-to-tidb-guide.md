## Flink高性能写入TiDB指南


本文旨在Flink写入TiDB场景下的代码实现和配置进行讨论，以满足海量数据的高性能写入需求。

**测试环境：**

- Flink: V1.13.5

- Scala: V2.12

- MySQL JDBC Connector: V8.0.27

- TiDB: V5.3.0


**实现高性能写入的必要条件：**

- 批量插入提高算子并行度
- 多线程并发写入

**测试数据源：**

虚拟数据源，在Job中生成无限量的模拟数据，数据结构：id bigint, productid int, name string, price int, cnt int

在Flink Job中创建成表：

```scala
val sourceDataStream = env.addSource(new MockOrderItemSource)
tableEnv.createTemporaryView("mock_orderitem", sourceDataStream)
```

**测试用例：**

**Flink SQL 表创建：**
示例语句：

```sql
CREATE TABLE order_item (
  id BIGINT,
  productId INT,
  name STRING,
  price DECIMAL(8,2),
  cnt INT, 
  PRIMARY KEY (`id`) NOT ENFORCED
) WITH (
  'connector' = 'jdbc',
  'url' = 'jdbc:mysql://<address>:4000/<database>?useServerPrepStmts=true&cachePrepStmts=true&rewriteBatchedStatements=true', 
  'driver' = 'com.mysql.jdbc.Driver',  
  'table-name' = 't_order_item',  
  'username' = 'your-user',  
  'password' = 'your-password',  
  'sink.buffer-flush.max-rows' = '200',  
  'sink.buffer-flush.interval' = '1',  
  'sink.parallelism' = '200'
)
```

关键参数说明：

- PRIMARY KEY (`id`) NOT ENFORCED: 在插入数据的目标表中指定主键，将会自动生成INSERT INTO …. ON DUPLICATE KEY UPDATE语句，实现UPSERT。

- JDBC连接字符串：
  - useServerPrepStmts=true: SQL语句基本相同，需要避免服务器重复解析SQL的开销
  
  - cachePrepStmts=true: 客户端缓存预处理语句
  
  - rewriteBatchedStatements=true: 批量写入的关键参数，将单条SQL改写为多个VALUES值SQL

  - sink.parallelism' = '200’: 算子并行度，决定了写入TiDB时的线程数![img](https://lh3.googleusercontent.com/Ya4OODl_de2I_L7ymU1jA4njDOnlP0hCdU6VAH000pBVVD6rz6tDfp08Mz_c2CKsI_zL_xNL45kTRMh7S1JDyx8G5mJJceV82RYn1iYkdkN6GwM8hfUV6BNtnUMRGYaHmk0R_J-d)运行时查看TiDB连接数此时增加了200个
  
  - 'sink.buffer-flush.max-rows' = '200' 与 'sink.buffer-flush.interval' = '1': 前者会直接决定批量写入的Batch Size。
    **实现一：** 通过对象化的方式写入，示例代码：  

    ```scala
    val orderItemTable = tableEnv.sqlQuery("SELECT id, productId, name, price, cnt FROM mock_orderitem")  
    orderItemTable.executeInsert("order_item")
    ```
  
    ​	General Log截取：![img](https://lh4.googleusercontent.com/Ba3bb5A75fWRiMer8u_5JT3Rgu6FWjawO4kw7cTXnK4HhMo__DI8ruThOH6jnAAmUUb2B6a0EZduTqCK7hbCM6wiiTOM93UvdLiW6j-oUUU1NfF8ky9mo9wtkHyXI-DPDA-N8W-l)
    ​	结论：根据“1. Flink SQL 表创建”中的配置，会以批量的方式写入，并将INSERT INTO自动转为INSERT INTO …… ON DUPLICATE KEY UPDATE语句。
  
    
  
    **实现二：** 通过Flink SQL进行写入，示例代码：  
  
    ```scala
    tableEnv.executeSql("INSERT INTO order_item (id, productId, name, price, cnt) select id, productId, name, price, cnt FROM mock_orderitem")
    ```
  
    ​	结论：结果同“实现一”，会以批量的方式写入，并将INSERT INTO自动转为INSERT INTO …… ON DUPLICATE KEY UPDATE语句。
  
    
  
    **实现三：** 调用JDBC Connector进行写入，本示例不依赖“1. Flink SQL 表创建”，示例代码：  
  
    ```scala
    val executionOptions = JdbcExecutionOptions.builder
    				.withBatchIntervalMs(1)
    				.withBatchSize(200)
    				.build
    val connectionOptions = (new JdbcConnectionOptions.JdbcConnectionOptionsBuilder)  						.withUrl("jdbc:mysql://<address>:4000/<database>?useServerPrepStmts=true&cachePrepStmts=true&rewriteBatchedStatements=true")  
    				.withDriverName("com.mysql.jdbc.Driver")
    				.withUsername("your-user")
            .withPassword("your-password")
            .build  
    var insertSQL = "INSERT INTO t_order_item (id, productId, name, price, cnt) values (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE id=values(id)"  
    val sb: JdbcStatementBuilder[OrderItem] = new JdbcStatementBuilder[OrderItem] {    override def accept(ps: PreparedStatement, t: OrderItem): Unit = {     
      		ps.setLong(1, t.id);     
      		ps.setInt(2, t.productId);
      		ps.setString(3, t.name);
      		ps.setInt(4, t.price);
      		ps.setInt(5, t.cnt);    
    	}   
    }  
    val mySink = JdbcSink.sink(insertSQL, sb, executionOptions, connectionOptions)  sourceDataStream.addSink(mySink).setParallelism(200)  
    env.execute("TiDB Batch Write Job")
    ```
  
    ​	结论：会以批量的方式写入，并将INSERT INTO自动转为INSERT INTO …… ON DUPLICATE KEY UPDATE语句。
  
    
  
    **实现四：** 获得数据，通过迭代器进行处理后再执行，示例代码：  
  
    ```scala
    val templateSQL = "INSERT INTO order_item (id, productId, name, price, cnt) values (%d, %d, '%s', %d, %d)"  
    val results = tableEnv.executeSql("select id, goodsId, goodsName, goodsPrice, goodsCnt from mock_orderitem")  
    val it = results.collect()  
    try while (it.hasNext) {   
      val row = it.next   
      val insertSQL = templateSQL.format(row.getField("id"), row.getField("productId"), row.getField("name"), row.getField("price"), row.getField("cnt")) 
      tableEnv.executeSql(insertSQL)  
    }  
    finally it.close()
    ```
  
    ​	General Log截取：![img](https://lh6.googleusercontent.com/9N396uwpoQyc5nU8C4yfhmzZa_NkLcUTxdoy1hpfaBgBV-rQ-5Bt3RSRUMIwA7U6Qacb-5rzStaFjwJ7tLT-aN65b-MBm8pRttzF06Gkbe0t7_4WXwXrDosjGuOr3ssOtr3lSeEN)
    ​	结论：无法实现批量写入，但可以将INSERT INTO 转换为INSERT INTO …… ON DUPLICATE KEY UPDATE。即使采用StatementSet，也无法实现批量写入（待进一步验证）。此种实现方式应予以避免。
  
    
  
    **数据源并行度：**
  
    - Kafka：Source或环境的并行设置需要与Kafka Topic Partition数量相一致。
    - 数据库：通常需要为1。
  
    
  
    **批量写入的QPS计算：**
  
    - 以本文中Batch Size为200为例，参照下图中Insert QPS最新值为279，得出实际QPS：QPS = 279 * 200 = 55,800条/秒
      ![img](https://lh5.googleusercontent.com/SaUy4rS0tlKjkODq6jEL-RzqvbC_UCTmbqSp7Dvj_gqWCyEdJWohPBRG-IgwrI1FBMgsFjNpyM3f1xMKMZz9d4i09ymEVHsLNuiMoiiLoa8A5O07RNbxskuieq4AwEXYR-wC9UWI)
