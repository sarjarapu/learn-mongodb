curDir=`pwd`
killall mongod
sleep 1 

rm -rf $curDir/* 
mkdir -p rs{1,2,3}/db certs client

echo "
# $curDir/rs1/mongod.conf
storage:
   dbPath: '$curDir/rs1/db'
systemLog:
   destination: file
   path: '$curDir/rs1/mongodb.log'
   logAppend: true
   logRotate: rename
replication:
   replSetName: 'rsApp'
processManagement:
   fork: true
net:
   port: 28001
   ssl:
      mode: preferSSL
      PEMKeyFile: '$curDir/rs1/server1.arjarapu.net.pem'
      PEMKeyPassword: 'secret_member'
      CAFile: '$curDir/rs1/rootCA.public.crt'
security:
   clusterAuthMode: x509

" | tee rs1/mongod.conf 
sleep 1 

cat rs1/mongod.conf |  sed 's/rs1/rs2/g' |  sed 's/28001/28002/g' |  sed 's/server1/server2/g' | tee rs2/mongod.conf 
cat rs1/mongod.conf |  sed 's/rs1/rs3/g' |  sed 's/28001/28003/g' |  sed 's/server1/server3/g' | tee rs3/mongod.conf 


################################################################################
# Localhost testing 
################################################################################
# Generate the Certificate Authority
caCertsPath='./certs'
caPassword='secret_ca'
caServerName='certauthority.arjarapu.net'

# Generate the private root key file - this file should be kept secure:
openssl genrsa -des3 -passout pass:$caPassword -out $caCertsPath/rootCA.private.key 4096
sleep 1
# Generate the public root certificate - it is our CAFile that has to be distributed among the servers and clients so they could validate each other’s certificates
openssl req -x509 -new -days 365  -passin pass:$caPassword -key $caCertsPath/rootCA.private.key -out $caCertsPath/rootCA.public.crt -subj "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Certification Authority/CN=$caServerName"
sleep 1


# Signature: createCertificate <role:omgr,client,member1,kmipMember1> <FQDN> <PEM Password> <CA Password> <CN>
createCertificate()
{
    serverRole=$1
    serverName=$2
    serverPassword=$3 
    caPassword=$4
    subject=$5

    caCertsPath='./certs'
    # Generate the private key file:
    openssl genrsa -des3 -passout pass:$serverPassword -out $caCertsPath/$serverRole.$serverName.private.key 4096 
    # Generate a Certificate Signing Request (CSR), ensure that the CN you specified matches the FQDN of the host
    openssl req -new -passin pass:$serverPassword -key $caCertsPath/$serverRole.$serverName.private.key -out $caCertsPath/$serverRole.$serverName.csr -subj $subject
    # Use the CSR to create a certificate signed with our root certificate
    openssl x509 -req -passin pass:$caPassword -in $caCertsPath/$serverRole.$serverName.csr -CA $caCertsPath/rootCA.public.crt -CAkey $caCertsPath/rootCA.private.key -CAcreateserial -out $caCertsPath/$serverRole.$serverName.public.crt -days 365
    # Concatenate them into a single .pem file - that is the PEMKeyFile option that should be used to start the mongod process
    cat $caCertsPath/$serverRole.$serverName.private.key $caCertsPath/$serverRole.$serverName.public.crt > $caCertsPath/$serverRole.$serverName.pem    
    # Verify that the .pem file can be validated with the root certificate that was used to sign it
    # That should return $serverRole.$serverName.pem: OK
    openssl verify -CAfile $caCertsPath/rootCA.public.crt $caCertsPath/$serverRole.$serverName.pem 
}

# Certificates: TLS for all members 
createCertificate 'member' 'server1.arjarapu.net' 'secret_member' "$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Databases/CN=server1.arjarapu.net"
createCertificate 'member' 'server2.arjarapu.net' 'secret_member' "$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Databases/CN=server2.arjarapu.net"
createCertificate 'member' 'server3.arjarapu.net' 'secret_member' "$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Databases/CN=server3.arjarapu.net"

# Certificate: Client
createCertificate 'client' 'client.arjarapu.net' 'secret_client' "$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Clients/CN=client.arjarapu.net"

# create 
userCN=$( openssl x509 -in  $caCertsPath/client.client.arjarapu.net.pem  -inform PEM -subject -nameopt RFC2253 -noout | cut -d' ' -f2 )

cat $caCertsPath/member.server1.arjarapu.net.private.key $caCertsPath/member.server1.arjarapu.net.public.crt > $caCertsPath/server1.arjarapu.net.pem 
cat $caCertsPath/member.server2.arjarapu.net.private.key $caCertsPath/member.server2.arjarapu.net.public.crt > $caCertsPath/server2.arjarapu.net.pem 
cat $caCertsPath/member.server3.arjarapu.net.private.key $caCertsPath/member.server3.arjarapu.net.public.crt > $caCertsPath/server3.arjarapu.net.pem 
cat $caCertsPath/client.client.arjarapu.net.private.key $caCertsPath/client.client.arjarapu.net.public.crt > $caCertsPath/client.arjarapu.net.pem 

cp $caCertsPath/rootCA.public.crt $caCertsPath/server1.arjarapu.net.pem  rs1/
cp $caCertsPath/rootCA.public.crt $caCertsPath/server2.arjarapu.net.pem  rs2/
cp $caCertsPath/rootCA.public.crt $caCertsPath/server3.arjarapu.net.pem  rs3/
cp $caCertsPath/rootCA.public.crt $caCertsPath/client.arjarapu.net.pem  client/

mongod --config rs1/mongod.conf
mongod --config rs2/mongod.conf
mongod --config rs3/mongod.conf

echo "

$userCN

"
mongo --port 28001  <<EOF
use admin
rs.initiate({_id: 'rsApp', 'members' : [{ '_id' : 0, 'host' : 'server1.arjarapu.net:28001' }]})
sleep(10000)
db.createUser({user: 'superuser', pwd: 'secret', roles: ['root']})
db.auth('superuser', 'secret')
rs.add({ host : 'server2.arjarapu.net:28002' })
rs.add({ host : 'server3.arjarapu.net:28003' })
db.getSiblingDB('\$external').runCommand({createUser: '$userCN', roles: [{role: 'root', db: 'admin'}]})
EOF


# login to server using x509 
mongo --host server1.arjarapu.net --port 28001 --ssl --sslPEMKeyFile client/client.arjarapu.net.pem --sslPEMKeyPassword secret_client --sslCAFile client/rootCA.public.crt <<EOF
use admin; 
db.getSiblingDB('\$external').auth({user: '$userCN', mechanism: 'MONGODB-X509'})
use social
db.people.insert({fname: 'shyam'})
EOF


echo "

mongo --host server1.arjarapu.net --port 28001 --ssl --sslPEMKeyFile client/client.arjarapu.net.pem --sslPEMKeyPassword secret_client --sslCAFile client/rootCA.public.crt
use admin; 
db.getSiblingDB('\$external').auth({user: '$userCN', mechanism: 'MONGODB-X509'})

"

