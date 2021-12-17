# 快速在AWS EC2上搭建TiDB集群

## 1. 在堡垒机上安装TiUP部署管理工具

   ```Bash
   curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
   source .bash_profile
   which tiup
   tiup cluster
   tiup update --self && tiup update cluster
   tiup --binary cluster
   ```

## 2. 快速配置EC2系统环境
   克隆Repo:
   ```Bash
   git clone https://github.com/liangfb/tidb-utils
   ```
   
   以下针对Amazon Linux 2操作系统  
   
   **配置TiKV和TiFlash节点：**
   ```bash
   cd tidb-utils/scripts/env/
   ```
   ```bash   
   ssh -i <your key file> ec2-user@nodeipaddr 'bash -s' < amzn_initial.sh tikv <data-volume-device>
   ```
   示例：
   ```bash
    ssh -i mykey.pem ec2-user@172.31.10.8 'bash -s' < amzn_initial.sh tikv nvme1n1
   ```

   **配置PD, TiDB和Monitor节点：**
   ```bash
    ssh -i <key file> ec2-user@nodeipaddr < amzn_initial.sh
   ```  

## 3. 准备拓扑文件

   编辑tidb-utils/scripts/env/mini_install_template.yaml文件，修改为对应的EC2 Private IP地址，
   如需要自定义配置各角色的运行参数，可参见附录部分。

## 4. 运行命令部署
   
   运行节点配置检查，如需自动修复，可添加***--apply***参数
   ```bash
   tiup cluster check mini_install_template.yaml -u ec2-user -i <key file>
   ```
   忽略os vendor amzn not supported错误，其他检查结果为Pass即可。

   运行部署命令：
   ```Bash
   tiup cluster deploy <cluster-name> <version> mini_install_template.yaml -u ec2-user -i <key file>
   ```
   示例：

   ```bash
   tiup cluster deploy tidb-cluster v5.2.2 mini_install_template.yaml -u ec2-user -i mykey.pem
   ```

   等待部署成功后启动集群：
   ```bash
   tiup cluster start <cluster-name>
   ```
   查看集群状态：
   ```bash
   tiup cluster display <cluster-name>
   ```

## 附一：常见参数

### 大量批量写入场景
   - TiKV:
   ```
   raftdb.defaultcf.write-buffer-size: 256MB
   raftstore.apply-pool-size: 4(CPU > 8cores)
   raftstore.store-pool-size: 4(CPU > 8cores)
   raftstore.raft-max-inflight-msgs: 1024
   raftdb.max-background-jobs: 8 or 16
   raftdb.defaultcf.soft-pending-compaction-bytes-limit: 384GB
   raftdb.defaultcf.hard-pending-compaction-bytes-limit: 512GB
   level0-slowdown-writes-trigger: 80
   level0-stop-writes-trigger: 144
   
   ``` 
   - TiDB:

   ```
   set global tidb_analyze_version = 1
   performance.committer-concurrency: 256
   ```

### 拓扑文件配置示例：
```yaml
server_configs:
  tikv:
    raftdb.defaultcf.write-buffer-size: 256MB
    ...
  tidb:
    ...
  pd:
    ...
```

## 附二：创建表时使数据能够均匀分布
- 使用AUTO_RANDOM代替AUTO_INCREMENT，来产生更加随机的自增值

示例：CREATE TABLE t (a bigint PRIMARY KEY AUTO_INCREMENT, b varchar(255));
- 为表定义region划分
如果表没有主键或主键不为数值型，建议增加：SHARD_ROW_ID_BITS

示例：create table t (a int, b int,index idx1(a)) shard_row_id_bits = 4
为表预切分region：

使用参数：pre_split_regions=n (n=2^n)

示例：create table t (a int, b int,index idx1(a)) pre_split_regions=2
SHARD_ROW_ID_BITS和pre_split_regions也可一起使用


