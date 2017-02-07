#!/bin/sh

# kill all existing mongod processes 
echo "killing all mongod processes"
killall mongod 
sleep 3

# clear all the existing directories
echo "Clearing and recreating the server & config folders"
rm -rf certs server1 server2 server3 

# create the data directories for all 3 mongod instances 
mkdir -p certs server{1,2,3}/{data,config}

createCertificate()
{
    certCAPassword=$1
    machineName=$2
    isCertAuth=$3
    options=''
    
    # create CA Certificate 
    openssl genrsa -des3 -passout pass:$certCAPassword -out certs/cert.authority.key 4096
    openssl req -new -x509 -days 3650 -passin pass:$certCAPassword -key certs/cert.authority.key -out certs/cert.authority.crt -subj "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Consulting/CN=certauthority.arjarapu.net"
    cat certs/cert.authority.key certs/cert.authority.crt > certs/cert.authority.pem

    openssl genrsa -des3 -passout pass:secretserver -out server.key 4096
    openssl req -new -passin pass:secretserver -key server.key -out server.csr -subj "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Consulting/CN=server1.arjarapu.net"
    openssl x509 -req -passin pass:secretca -days 365 -in server.csr -CA certauthority.crt -CAkey certauthority.key -set_serial 01 -out server.crt
    cat server.key server.crt > server.pem

    openssl genrsa -des3 -passout pass:secretclient -out client.key 4096
    openssl req -new -passin pass:secretclient -key client.key -out client.csr -subj "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Consulting/CN=client.arjarapu.net"
    openssl x509 -req -passin pass:secretca -days 365 -in client.csr -CA certauthority.crt -CAkey certauthority.key -set_serial 01 -out client.crt
    cat client.key client.crt > client.pem
}

createConfigAndStartMongoD() 
{     
      serverPath=$1
      serverPort=$2
      serverName=$3
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
   ssl:
      mode: requireSSL
      PEMKeyFile: $serverPath/$serverName.pem
      PEMKeyPassword: secretPassworFor$serverName
      CAFile: $serverPath/cert.authority.pem
      clusterAuthMode: 
replication:
   replSetName: rs0
security:
   authorization: enabled
" | tee $serverPath/mongod.conf 

chmod 400 $serverPath/keyfile
sleep 1
mongod --config $serverPath/mongod.conf 

}

createConfigAndStartMongoD `pwd`/server1 28000 ShyamsMacBookPro_28000
createConfigAndStartMongoD `pwd`/server2 28001 ShyamsMacBookPro_28000
createConfigAndStartMongoD `pwd`/server3 28002 ShyamsMacBookPro_28000


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


