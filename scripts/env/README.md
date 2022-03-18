# TiDB Nodes Initialization

Install the prerequisites and configuration

Usage Info:

Example: run on AWS EC2

For TiKV and TiFlash nodes:

​	    ssh -i <key file> username@nodeip 'bash -s' < amzn_initial.sh [Role Name] [Device Name]

Example:

```shell
ssh -i yourkey.pem ec2-user@172.xx.xx.8 'bash -s' < amzn_initial.sh tikv nvme1n1
```
Initialize TiDB, PD and other nodes;

​        ssh -i <key file> username@nodeip < amzn_initial.sh

Example:

```shell
ssh -i yourkey.pem ec2-user@172.xx.xx.6 < amzn_initial.sh
```
