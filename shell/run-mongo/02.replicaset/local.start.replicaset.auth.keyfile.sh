#!/bin/sh

# kill all existing mongod processes 
echo "killing all mongod processes"
killall mongod 
sleep 3

# clear all the existing directories
echo "Clearing and recreating the server & config folders"
rm -rf server1 server2 server3 

# create the data directories for all 3 mongod instances 
mkdir -p server{1,2,3}/data


createConfigAndStartMongoD() 
{     
      serverPath=$1
      serverPort=$2

echo 'secretPasscode' | openssl sha1 -sha512  | sed 's/(stdin)= //g' > $serverPath/keyfile

echo "
systemLog:
   destination: file
   path: $serverPath/mongod.log
   logAppend: true
storage:
   dbPath: $serverPath/data
processManagement:
   fork: true
   pidFilePath: $serverPath/mongod.pid
net:
   port: $serverPort
replication:
   replSetName: rs0
security:
   authorization: enabled
   keyFile: $serverPath/keyfile
" | tee $serverPath/mongod.conf 

chmod 400 $serverPath/keyfile
sleep 1
mongod --config $serverPath/mongod.conf 

}

createConfigAndStartMongoD `pwd`/server1 28000
createConfigAndStartMongoD `pwd`/server2 28001
createConfigAndStartMongoD `pwd`/server3 28002


sleep 2

machineName=`uname -n`

mongo --port 28000 <<EOF
rs.initiate()

sleep(3000)
use admin 
db.createUser({user: 'superuser', pwd: 'secret', roles: ['root']})
db.auth('superuser', 'secret')

sleep(3000)
rs.add('$machineName:28001')
rs.add('$machineName:28002')
EOF


