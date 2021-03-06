#!/bin/bash

echo 'INFO: This script is used to initialize the environment for deploy TiDB cluster on Amazon Linux 2.'
echo 'Please specify the [storage] [device] parameters for initialize the TiKV node. Example: $> ./script.sh tikv nvme1n1'
echo 'Your parameters:'
role=${1:-'others'}
dev=${2:-'nvme1n1'}
echo 'The role is:' $role
echo 'The device is:' $dev
echo 'The initialization will start after 5 seconds.'
sleep 5
sudo apt-get -y upgrade
sudo apt-get -y update
sudo apt-get -y install gcc make numactl ntp ntpstat sshpass
sudo mkdir /tidb-data
if [ "$role" = "tikv" ] || [ "$role" = "tiflash" ]
then
    echo 'Initializing disks...'
    sudo mkfs -t ext4 /dev/${dev}
    sudo mount /dev/${dev} /tidb-data/ -o nodelalloc,noatime
    lsblk -f   
    uuid=$(sudo blkid | grep /dev/${dev} | cut -d '=' -f 2 | cut -d ' ' -f 1 | xargs)
    echo $uuid
    sudo bash -c "echo UUID=${uuid}     /tidb-data  ext4   defaults,nodelalloc,noatime  0   2 >> /etc/fstab"
    mount -t ext4
    echo '/etc/fstab:'
    cat /etc/fstab
    echo '/etc/fstab has been modified, please review and ensure the content is correct.'
    sleep 5
fi

systemctl status ntp

sudo bash -c "echo vm.swappiness = 0 >> /etc/sysctl.conf"
sudo swapoff -a

#Config network parameters
sudo bash -c "echo fs.file-max = 1000000 >> /etc/sysctl.conf"
sudo bash -c "echo net.core.somaxconn = 32768 >> /etc/sysctl.conf"
sudo bash -c "echo net.ipv4.tcp_syncookies = 0 >> /etc/sysctl.conf"
sudo bash -c "echo vm.overcommit_memory = 1 >> /etc/sysctl.conf"
sudo sysctl -p

#Config Limitation
sudo bash -c 'cat << EOF >>/etc/security/limits.conf
tidb           soft    nofile          1000000
tidb           hard    nofile          1000000
tidb           soft    stack          32768
tidb           hard    stack          32768
EOF'

#Disable TPH
sudo bash -c "echo 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' >> /etc/rc.local"
sudo bash -c "echo 'echo never > /sys/kernel/mm/transparent_hugepage/defrag' >> /etc/rc.local"
sudo chmod +x /etc/rc.local
sudo bash -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
sudo bash -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag"

echo '/etc/fstab:'
cat /etc/fstab

echo 'Configuration completed.'
#echo 'Initialization completed, it will reboot after 5 seconds.'
#sleep 5
#sudo reboot
