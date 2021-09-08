#!/bin/bash
sudo su
echo 'INFO: This script is used to initialize the environment for deploy TiDB cluster on Amazon Linux 2.'
echo 'Please specify the [storage] [device] parameters for initialize the TiKV node. Example: $> ./script.sh tikv nvme1n1'
echo 'Your parameters:'

role=${1:-'others'}
dev=${2:-'nvme1n1'}
echo 'The role is:' $role
echo 'The device is:' $dev
echo 'The initialization will start after 5 seconds.'
sleep 5

yum -y install gcc gcc-c++ make numactl chrony wget
wget https://github.com/liangfb/assets/raw/master/projects/sshpass-1.08.tar.gz
tar zxvf sshpass-1.08.tar.gz
cd sshpass-1.08
./configure
make install
cd ..
mkdir /tidb-data
if [ "$role" = "tikv" ]
then
    echo 'Initializing disks...'
    mkfs -t ext4 /dev/${dev}
    mount /dev/${dev} /tidb-data/ -o nodelalloc,noatime,barrier=0
    lsblk -f
    uuid=$(blkid | grep ${dev} | awk 'NR==1' | cut -d "=" -f 2 | cut -d " " -f 1 | xargs)
    echo "UUID=${uuid}     /tidb-data  ext4   defaults,nodelalloc,noatime,barrier=0  0   2" >> /etc/fstab
    mount -t ext4
    echo '/etc/fstab has been modified, please review and ensure the content is correct.'
    sleep 5
    cat /etc/fstab
fi

echo "vm.swappiness = 0">> /etc/sysctl.conf
swapoff -a && swapon -a
sysctl -p

#Config NTP service & timezone
systemctl restart chronyd
systemctl enable chronyd
chronyc sources -v
chronyc tracking

sed -i "s/ZONE=\"UTC\"/ZONE=\"Asia\/shanghai\"/g" /etc/sysconfig/clock
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

#Config network parameters
echo "fs.file-max = 1000000">> /etc/sysctl.conf
echo "net.core.somaxconn = 4096">> /etc/sysctl.conf
echo "net.ipv4.tcp_tw_recycle = 0">> /etc/sysctl.conf
echo "net.ipv4.tcp_syncookies = 0">> /etc/sysctl.conf
echo "vm.overcommit_memory = 1">> /etc/sysctl.conf
sysctl -p

#Config Limitation
cat << EOF >>/etc/security/limits.conf
tidb           soft    nofile          1000000
tidb           hard    nofile          1000000
tidb           soft    stack          32768
tidb           hard    stack          32768
EOF

#Disable TPH
echo 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' >> /etc/rc.local
echo 'echo never > /sys/kernel/mm/transparent_hugepage/defrag' >> /etc/rc.local
chmod +x /etc/rc.d/rc.local

echo 'Initialization completed, it will reboot after 5 seconds.'
sleep 5
reboot