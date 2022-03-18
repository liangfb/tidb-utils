#!/bin/bash
if [ $# -lt 5 ]
then
echo "Usage: init_topology.sh <template file> <tikv1> <tidb1> <pd1> <monitor> [tikv2] [tikv3] [tidb2] [pd2] [pd3]"
return -1
fi

echo 'Config topology file...'
echo 'topology file:' $1
echo 'tikv node 1:' $2
echo 'tidb node 1:' $3
echo 'pd node 1:' $4
echo 'monitor node:' $5

sed -i "s/{pd-1}/$2/g" $1
sed -i "s/{tidb-1}/$3/g" $1
sed -i "s/{tikv-1}/$4/g" $1
sed -i "s/{monitor}/$5/g" $1

sed -i "s/{tikv-2}/$6/g" $1
sed -i "s/{tikv-3}/$7/g" $1
sed -i "s/{tidb-2}/$8/g" $1
sed -i "s/{pd-2}/$9/g" $1
sed -i "s/{pd-3}/$10/g" $1

return 0

