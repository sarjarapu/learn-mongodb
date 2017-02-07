#!/bin/sh 

# kill all existing mongod processes 
echo "killing all mongod processes"
killall mongod 


sleep 3

# clear all the existing directories
echo "Clearing and recreating the server & config folders"
rm -rf server{1,2,3} config

# create the data directories for all 3 mongod instances 
mkdir -p server{1,2,3}/data config

createSubordinateCA()
{
      password=$1
      machineName=$2
      isCertAuth=$3
      options=''
      if $isCertAuth; then
            options=' -x509 -days 3650 '
      fi 


      openssl genrsa -des3 -passout pass:$password -out ./config/$machineName.key 4096
      openssl req -new `$options` -passin pass:$password -key ./config/$machineName.key -out ./config/$machineName.crt -subj "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Consulting/CN=$machineName.arjarapu.net"
      cat ./config/$machineName.key ./config/$machineName.crt > ./config/$machineName.pem
}

# worked from docs 
# https://docs.mongodb.com/manual/tutorial/configure-ssl/
openssl req -newkey rsa:2048 -new -x509 -days 365 -nodes -out mongodb-cert.crt -keyout mongodb-cert.key -subj "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Consulting/CN=certauthority.arjarapu.net"
cat mongodb-cert.key mongodb-cert.crt > mongodb-cert.pem
mongod  --sslMode requireSSL --sslPEMKeyFile mongodb.pem --dbpath ./data --logpath ./mongod.log --fork --port 22010 --sslAllowConnectionsWithoutCertificates
mongo --ssl --sslCAFile mongodb.pem --host certauthority.arjarapu.net --port 22010


# SSL: PEMKey + Password 
# https://docs.mongodb.com/manual/tutorial/configure-ssl/
openssl genrsa -des3 -passout pass:secretca -out certauthority.key 4096
openssl req -new -x509 -days 3650 -passin pass:secretca -key certauthority.key -out certauthority.crt -subj "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Consulting/CN=certauthority.arjarapu.net"
cat certauthority.key certauthority.crt > certauthority.pem
mongod  --sslMode requireSSL --sslPEMKeyFile certauthority.pem --sslPEMKeyPassword secretca --dbpath ./data --logpath ./mongod.log --fork --port 22010 --sslAllowConnectionsWithoutCertificates
mongo --ssl --sslCAFile certauthority.pem --sslPEMKeyPassword secretca --host certauthority.arjarapu.net --port 22010


# SSL: PEMKey + Password + CA File
openssl genrsa -des3 -passout pass:secretca -out certauthority.key 4096
openssl req -new -x509 -days 3650 -passin pass:secretca -key certauthority.key -out certauthority.crt -subj "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Consulting/CN=certauthority.arjarapu.net"
cat certauthority.key certauthority.crt > certauthority.pem

openssl genrsa -des3 -passout pass:secretserver -out server.key 4096
openssl req -new -passin pass:secretserver -key server.key -out server.csr -subj "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Consulting/CN=server1.arjarapu.net"
openssl x509 -req -passin pass:secretca -days 365 -in server.csr -CA certauthority.crt -CAkey certauthority.key -set_serial 01 -out server.crt
cat server.key server.crt > server.pem

openssl genrsa -des3 -passout pass:secretclient -out client.key 4096
openssl req -new -passin pass:secretclient -key client.key -out client.csr -subj "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Consulting/CN=client.arjarapu.net"
openssl x509 -req -passin pass:secretca -days 365 -in client.csr -CA certauthority.crt -CAkey certauthority.key -set_serial 01 -out client.crt
cat client.key client.crt > client.pem

mongod  --sslMode requireSSL --sslPEMKeyFile server.pem --sslPEMKeyPassword secretserver --sslCAFile certauthority.pem --dbpath ./data --logpath ./mongod.log --fork --port 22010
mongo --ssl --sslPEMKeyFile client.pem --sslCAFile certauthority.pem --sslPEMKeyPassword secretclient --host server1.arjarapu.net --port 22010


# mongod --replSet <name> --sslMode requireSSL --clusterAuthMode x509 --sslClusterFile <path to membership certificate and key PEM file> --sslPEMKeyFile <path to SSL certificate and key PEM file> --sslCAFile <path to root CA PEM file>


# openssl req -newkey rsa:2048 -new -x509 -days 365 -out mongodb-cert.crt -keyout mongodb-cert.key -subj "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Consulting/CN=$machineName.arjarapu.net"
# cat mongodb-cert.key mongodb-cert.crt > mongodb.pem
# mongod  --sslMode requireSSL --sslPEMKeyFile mongodb.pem --dbpath ./data --logpath ./mongod.log --fork --port 22010 --sslAllowConnectionsWithoutCertificates
# mongo --ssl --sslCAFile mongodb.pem --host certauthority.arjarapu.net --port 22010



# mongod --sslPEMKeyFile cert.authority.pem --sslMode requireSSL --sslAllowConnectionsWithoutCertificates --sslPEMKeyPassword secretca --dbpath ./data --logpath mongod.log --fork --port 22010
# mongo --ssl --host certauthority.arjarapu.net --port 22010 --sslPEMKeyFile cert.authority.pem --sslPEMKeyPassword secretca

# openssl genrsa -des3 -passout pass:secretca -out ../config/cert.authority.key 4096
# openssl req -new -x509 -days 3650 -passin pass:secretca -key ../config/cert.authority.key -out ../config/cert.authority.crt -subj "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Consulting/CN=certauthority.arjarapu.net"
# cat ../config/cert.authority.key ../config/cert.authority.crt > ../config/cert.authority.pem


createSubordinateCA secretca cert.authority true
createSubordinateCA secretserver server1 false 
createSubordinateCA secretserver server2 false 
createSubordinateCA secretserver server3 false

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
   ssl:
      mode: requireSSL
      PEMKeyFile: serverPath/serverName.pem
      PEMKeyPassword: secretserver
      CAFile: serverPath/cert.authority.pem
replication:
   replSetName: rsProject
EOF

cp ./config/cert.authority.pem ./server1
cp ./config/cert.authority.pem ./server2
cp ./config/cert.authority.pem ./server3

cp ./config/server1.pem ./server1
cp ./config/server2.pem ./server2
cp ./config/server3.pem ./server3

# create 3 config servers
sed "s#serverPath#`pwd`/server1#g" ./config/mongod.conf | sed 's/serverPort/27000/g' | sed 's/serverName/server1/g' > ./server1/mongod.conf
sed "s#serverPath#`pwd`/server2#g" ./config/mongod.conf | sed 's/serverPort/27001/g' | sed 's/serverName/server2/g' > ./server2/mongod.conf
sed "s#serverPath#`pwd`/server3#g" ./config/mongod.conf | sed 's/serverPort/27002/g' | sed 's/serverName/server3/g' > ./server3/mongod.conf


mongod --config ./server1/mongod.conf 
mongod --config ./server2/mongod.conf 
mongod --config ./server3/mongod.conf 


# mongo --port 22010 --ssl -sslPEMKeyFile mongodb.pem --host Shyams-MacBook-Pro.local --sslAllowInvalidCertificates

