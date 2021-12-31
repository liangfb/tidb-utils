# Quickly build a TiDB cluster on AWS EC2

[中文版](install_on_aws_ec2.md)

## 1. Install TiUP tool on the bastion host 

   ```Bash
   curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
   source .bash_profile
   which tiup
   tiup cluster
   tiup update --self && tiup update cluster
   tiup --binary cluster
   ```

## 2. Easy configuration of EC2 OS environment
   Clone Github repo:
   ```Bash
   git clone https://github.com/liangfb/tidb-utils
   ```

   The following is for Amazon Linux 2 operating system.

   **Configure TiKV and TiFlash nodes:**
   ```bash
   cd tidb-utils/scripts/env/
   ```
   ```bash   
   ssh -i <your key file> ec2-user@nodeipaddr 'bash -s' < amzn_initial.sh tikv <data-volume-device>
   ```
   Example:
   ```bash
    ssh -i mykey.pem ec2-user@172.31.10.8 'bash -s' < amzn_initial.sh tikv nvme1n1
   ```

   **Configure PD, TiDB and Monitor nodes:**
   ```bash
    ssh -i <key file> ec2-user@nodeipaddr < amzn_initial.sh
   ```

## 3. Prepare topology file

   Edit the tidb-utils/scripts/env/mini_install_template.yaml file and modify it to the EC2 Private IP address,
   If you need to customize the parameters of each role, please refer to the appendix.

## 4. Run deployment command

   Run environment check on nodes, if you need automatic repair, you can add ***--apply*** parameter

   ```bash
   tiup cluster check mini_install_template.yaml -u ec2-user -i <key file>
   ```
   Ignore the "os vendor amzn not supported" error and ensure that the results of other check items are Pass.

   Run deployment command:
   ```Bash
   tiup cluster deploy <cluster-name> <version> mini_install_template.yaml -u ec2-user -i <key file>
   ```
   Example:

   ```bash
   tiup cluster deploy tidb-cluster v5.2.2 mini_install_template.yaml -u ec2-user -i mykey.pem
   ```

   Wait for the deployment to be successful and start the cluster:
   ```bash
   tiup cluster start <cluster-name>
   ```
   View cluster status:
   ```bash
   tiup cluster display <cluster-name>
   ```

## Appendix 1: Suggested parameters

### A large number of batch writes
   - TiKV:
   ```
   raftdb.defaultcf.write-buffer-size: 256MB
   raftstore.apply-pool-size: 4(CPU > 8cores)
   raftstore.store-pool-size: 4(CPU > 8cores)
   raftstore.raft-max-inflight-msgs: 1024
   raftdb.max-background-jobs: 8 or 16
   raftdb.defaultcf.soft-pending-compaction-bytes-limit: 384GB
   raftdb.defaultcf.hard-pending-compaction-bytes-limit: 512GB
   rocksdb.defaultcf.level0-slowdown-writes-trigger: 80
   rocksdb.defaultcf.level0-stop-writes-trigger: 144
   
   ```
   - TiDB:

   ```
   set global tidb_analyze_version = 1
   performance.committer-concurrency: 256
   ```

### Topology file configuration example:
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

## Appendix 2：Make data evenly distributed when creating tables
- Use **AUTO_RANDOM** instead of AUTO_INCREMENT to generate random number.

  Example: CREATE TABLE t (a bigint PRIMARY KEY AUTO_INCREMENT, b varchar(255));

- Set the number of bits of the shards

  For the tables with a non-integer primary key or no primary key, you can configure **SHARD_ROW_ID_BITS**

  Example: create table t (a int, b int,index idx1(a)) shard_row_id_bits = 4;

- Pre-spilts tables into the number of regions, configure **PRE_SPLIT_REGIONS**

  pre_split_regions=n (n=2^n) 

  Example: create table t (a int, b int,index idx1(a)) shard_row_id_bits = 4 pre_split_regions=2;



