#!/bin/bash
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
