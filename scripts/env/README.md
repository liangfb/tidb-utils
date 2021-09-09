# TiDB Nodes Initialization

Install the prerequisites and configuration

Usage Info:

Example: run on AWS EC2

Initialize TiKV nodes:
```
ssh -i <key file> username@nodeaddr 'bash -s' < amzn_initial.sh tikv nvme1n1
```
Initialize TiDB, PD and other nodes;
```
ssh -i <key file> username@nodeaddr < amzn_initial.sh
```
