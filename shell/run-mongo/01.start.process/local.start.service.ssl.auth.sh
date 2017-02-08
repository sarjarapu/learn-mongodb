#!/bin/sh

# kill all existing mongod processes 
echo "killing all mongod processes"
killall mongod 
sleep 3

# clear all the existing directories
echo "Clearing and recreating the certs & data folders"
rm -rf server1 certs client

mkdir -p server1/{certs,data,conf} certs client/certs


createCACertificate()
{
    # create CA Certificate 
    cpath=$1
    cpass=$2
    openssl genrsa -des3 -passout pass:$cpass -out $cpath/rootca.private.key 4096
    openssl req -new -x509 -days 3650 -passin pass:$cpass -key $cpath/rootca.private.key -out $cpath/rootca.public.crt -subj "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Consulting/CN=certauthority.arjarapu.net"
    cat $cpath/rootca.private.key $cpath/rootca.public.crt > $cpath/rootca.pem
}



createServerCertificate()
{
    # create server Certificate 
    cpath=$1
    cpass=$2

    spassword=$4
    sname=$5
    scpath=$3/certs

    openssl genrsa -des3 -passout pass:$spassword -out $scpath/$sname.private.key 4096
    openssl req -new -passin pass:$spassword -key $scpath/$sname.private.key -out $scpath/$sname.csr -subj "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Consulting/CN=$sname.arjarapu.net"
    openssl x509 -req -extfile $cpath/extensions.conf -passin pass:$cpass -days 365 -in $scpath/$sname.csr -CA $cpath/rootca.public.crt -CAkey $cpath/rootca.private.key -set_serial 01 -out $scpath/$sname.public.crt
    cat $scpath/$sname.private.key $scpath/$sname.public.crt > $scpath/$sname.pem
}

machineName=`uname -n`


# Generate the Certificate Authority
caCertsPath=`pwd`/certs
caPassword=secret_ca

# Create the extensions file 
echo "[extensions]
keyUsage = digitalSignature
extendedKeyUsage = clientAuth" | tee $caCertsPath/extensions.conf 
sleep 1

createCACertificate $caCertsPath $caPassword
sleep 2

# Generate the certificate for server1 and sign it with ca 
serverName=server1
serverPath=`pwd`/server1
serverPassword=secret_$serverName
serverPort=28000
createServerCertificate $caCertsPath $caPassword $serverPath $serverPassword $serverName
sleep 2


# Generate the certificate for client and sign it with ca 
clientName=client
clientPath=`pwd`/client
clientPassword=secret_$clientName
createServerCertificate $caCertsPath $caPassword $clientPath $clientPassword $clientName
sleep 2


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
      PEMKeyFile: $serverPath/certs/$serverName.pem
      PEMKeyPassword: $serverPassword
      CAFile: $caCertsPath/rootca.public.crt
security:
#   clusterAuthMode: x509
   authorization: enabled   
" | tee $serverPath/conf/mongod.conf 

mongod --config $serverPath/conf/mongod.conf 
echo "mongo --host server1.arjarapu.net --port 28000 --ssl --sslCAFile certs/rootca.public.crt --sslPEMKeyFile client/certs/client.pem --sslPEMKeyPassword secret_client"

clientSubject=`openssl x509 -in $clientPath/certs/client.pem -inform PEM -subject -nameopt RFC2253 | grep subject | cut -d' ' -f2`
