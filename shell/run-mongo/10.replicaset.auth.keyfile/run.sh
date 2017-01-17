#!/bin/sh 

# kill all existing mongod processes 
echo "killing all mongod processes"
killall mongod 


sleep 3

# clear all the existing directories
echo "Clearing and recreating the server & config folders"
rm -rf server1 server2 server3 config

# create the data directories for all 3 mongod instances 
mkdir -p server1/data server2/data server3/data config

# create a mongod.conf placeholder file 
cat <<EOF > ./config/mongod.conf 
systemLog:
   destination: file
   path: serverPath/mongod.log
   logAppend: true
storage:
   dbPath: serverPath/data
   journal:
      enabled: true
processManagement:
   fork: true
   pidFilePath: serverPath/mongod.pid
net:
   port: serverPort
replication:
   replSetName: rsProject
#security:
#   authorization: enabled
#   keyFile: serverPath/keyfile
EOF




# create the shared keyfile using base64 with 1024 chars in it 
# Whats the logic between 755 and 1024?
echo "Generating the keyfile for replicaset and copying mongod.conf files "
openssl rand -base64 755 > ./config/keyfile 
# make sure only you can read it 
chmod 400 ./config/keyfile

# copy the keyfile into mongod folders 
cp ./config/keyfile server1
cp ./config/keyfile server2
cp ./config/keyfile server3

# create 3 config servers
sed "s#serverPath#`pwd`/server1#g" ./config/mongod.conf | sed 's/serverPort/27000/g' > ./server1/mongod.conf
sed "s#serverPath#`pwd`/server2#g" ./config/mongod.conf | sed 's/serverPort/27001/g' > ./server2/mongod.conf
sed "s#serverPath#`pwd`/server3#g" ./config/mongod.conf | sed 's/serverPort/27002/g' > ./server3/mongod.conf


sleep 3

# start the mongod instances 
echo "Starting the mongod processes using the config files"
mongod --config ./server1/mongod.conf 
mongod --config ./server2/mongod.conf 
mongod --config ./server3/mongod.conf 


sleep 3


# add new user and shutdown the servers 
echo "Configuring the replicaset and Adding Shyam (root) user"
mongo --port 27000 --eval 'rs.initiate();'
sleep 3
mongo --port 27000 --eval 'rs.add("Shyams-MacBook-Pro.local:27001");rs.add("Shyams-MacBook-Pro.local:27002")'
sleep 3
mongo admin --port 27000 --eval 'db.createUser({user: "shyam", pwd: "secret", roles: ["root"]});'
sleep 5


echo "Shutting down the replicaset so that we can enable the security soon"
mongo admin --port 27001 --eval 'db.shutdownServer({force: true})'
sleep 3
mongo admin --port 27002 --eval 'db.shutdownServer({force: true})'
sleep 3
mongo admin --port 27000 --eval 'db.shutdownServer({force: true})'
sleep 3

# enable the security and start the mongod processes 
sed "s/#//g" ./server1/mongod.conf > ./server1/mongod.new.conf
sed "s/#//g" ./server2/mongod.conf > ./server2/mongod.new.conf
sed "s/#//g" ./server3/mongod.conf > ./server3/mongod.new.conf


mv ./server1/mongod.new.conf ./server1/mongod.conf 
mv ./server2/mongod.new.conf ./server2/mongod.conf 
mv ./server3/mongod.new.conf ./server3/mongod.conf 

sleep 3 

# starting the mongod instances with the authentication enabled 
echo "Starting the mongod processes using the new onfig files using authenticaiton enabled"
mongod --config ./server1/mongod.conf 
mongod --config ./server2/mongod.conf 
mongod --config ./server3/mongod.conf 

sleep 10





