#!/bin/sh

# clear up the directories
killall mongod mongos
sleep 2
rm -rf data

# create required directories 
mkdir -p data/config/cs1/configdb data/config/cs2/configdb data/config/cs3/configdb
mkdir -p data/shards/s1/rs1/db data/shards/s1/rs2/db data/shards/s1/rs3/db
mkdir -p data/shards/s2/rs1/db data/shards/s2/rs2/db data/shards/s2/rs3/db
mkdir -p data/mongos/s1 data/mongos/s2

# create 3 config servers
sed 's/28019/29010/g' configs/cfgsvr.conf | sed 's/cs1/cs1/g' > data/config/cs1/mongod.conf
sed 's/28019/29011/g' configs/cfgsvr.conf | sed 's/cs1/cs2/g' > data/config/cs2/mongod.conf
sed 's/28019/29012/g' configs/cfgsvr.conf | sed 's/cs1/cs3/g' > data/config/cs3/mongod.conf


# create 6 mongod servers
sed 's/28019/29020/g' configs/mongod.conf | sed 's/shard1/shard1/g' | sed 's/rs1/rs1/g' | sed 's/sh1/s1/g' > data/shards/s1/rs1/mongod.conf
sed 's/28019/29021/g' configs/mongod.conf | sed 's/shard1/shard1/g' | sed 's/rs1/rs2/g' | sed 's/sh1/s1/g' > data/shards/s1/rs2/mongod.conf
sed 's/28019/29022/g' configs/mongod.conf | sed 's/shard1/shard1/g' | sed 's/rs1/rs3/g' | sed 's/sh1/s1/g' > data/shards/s1/rs3/mongod.conf

sed 's/28019/29030/g' configs/mongod.conf | sed 's/shard1/shard2/g' | sed 's/rs1/rs1/g' | sed 's/sh1/s2/g' > data/shards/s2/rs1/mongod.conf
sed 's/28019/29031/g' configs/mongod.conf | sed 's/shard1/shard2/g' | sed 's/rs1/rs2/g' | sed 's/sh1/s2/g' > data/shards/s2/rs2/mongod.conf
sed 's/28019/29032/g' configs/mongod.conf | sed 's/shard1/shard2/g' | sed 's/rs1/rs3/g' | sed 's/sh1/s2/g' > data/shards/s2/rs3/mongod.conf


# create 2 mongos servers
sed 's/28019/29000/g' configs/mongos.conf | sed 's/s1/s1/g' > data/mongos/s1/mongod.conf
sed 's/28019/29001/g' configs/mongos.conf | sed 's/s1/s2/g' > data/mongos/s2/mongod.conf



# start all mongod processes 
mongod -f data/config/cs1/mongod.conf
mongod -f data/config/cs2/mongod.conf
mongod -f data/config/cs3/mongod.conf

mongod -f data/shards/s1/rs1/mongod.conf
mongod -f data/shards/s1/rs2/mongod.conf
mongod -f data/shards/s1/rs3/mongod.conf

mongod -f data/shards/s2/rs1/mongod.conf
mongod -f data/shards/s2/rs2/mongod.conf
mongod -f data/shards/s2/rs3/mongod.conf

sleep 3

mongos -f data/mongos/s1/mongod.conf
mongos -f data/mongos/s2/mongod.conf

sleep 3

# Initiate replicaset and add secondaries 
mongo --port 29020 < js/initiateRS.js
sed "s/2902/2903/g" js/initiateRS.js | sed 's/shard1/shard2/g' | mongo --port 29030
sleep 5

mongo --port 29000 < js/addShards.js



