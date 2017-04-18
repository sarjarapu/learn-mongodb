###############################################################
# Create certificates required for Ops Manager demo 
###############################################################

# Generate the Certificate Authority
caCertsPath='./scripts/certs'
caPassword='secret_ca'
caServerName='ec2-54-187-50-205.us-west-2.compute.amazonaws.com'

# Generate the private root key file - this file should be kept secure:
openssl genrsa -des3 -passout pass:$caPassword -out $caCertsPath/rootCA.private.key 4096

# Generate the public root certificate - it is our CAFile that has to be distributed among the servers and clients so they could validate each other’s certificates
openssl req -x509 -new -days 365  -passin pass:$caPassword -key $caCertsPath/rootCA.private.key -out $caCertsPath/rootCA.public.crt -subj "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Certification Authority/CN=$caServerName"

# Signature: createCertificate <role:omgr,client,member1,kmipMember1> <FQDN> <PEM Password> <CA Password> <CN>
createCertificate()
{
    serverRole=$1
    serverName=$2
    serverPassword=$3 
    caPassword=$4
    subject=$5

    caCertsPath='./scripts/certs'

    # Generate the private key file:
    openssl genrsa -des3 -passout pass:$serverPassword -out $caCertsPath/$serverRole.$serverName.private.key 4096 

    # Generate a Certificate Signing Request (CSR), ensure that the CN you specified matches the FQDN of the host
    openssl req -new -passin pass:$serverPassword -key $caCertsPath/$serverRole.$serverName.private.key -out $caCertsPath/$serverRole.$serverName.csr -subj $subject
    #  "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Operations/CN=$serverName"

    # Use the CSR to create a certificate signed with our root certificate
    openssl x509 -req -passin pass:$caPassword -in $caCertsPath/$serverRole.$serverName.csr -CA $caCertsPath/rootCA.public.crt -CAkey $caCertsPath/rootCA.private.key -CAcreateserial -out $caCertsPath/$serverRole.$serverName.public.crt -days 365


    # Concatenate them into a single .pem file - that is the PEMKeyFile option that should be used to start the mongod process
    cat $caCertsPath/$serverRole.$serverName.private.key $caCertsPath/$serverRole.$serverName.public.crt > $caCertsPath/$serverRole.$serverName.pem
    
    # Verify that the .pem file can be validated with the root certificate that was used to sign it
    # That should return $serverRole.$serverName.pem: OK
    openssl verify -CAfile $caCertsPath/rootCA.public.crt $caCertsPath/$serverRole.$serverName.pem 
}


# Certificate: Ops Manager WebServer
createCertificate 'omgr' 'ec2-54-187-50-205.us-west-2.compute.amazonaws.com' 'secret_omgr' "$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Operations/CN=ec2-54-187-50-205.us-west-2.compute.amazonaws.com"

# Certificates: TLS for all members 
createCertificate 'member' 'ip-172-31-13-231.us-west-2.compute.internal' 'secret_member' "$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Databases/CN=ip-172-31-13-231.us-west-2.compute.internal"
createCertificate 'member' 'ip-172-31-15-77.us-west-2.compute.internal' 'secret_member' "$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Databases/CN=ip-172-31-15-77.us-west-2.compute.internal"
createCertificate 'member' 'ip-172-31-10-208.us-west-2.compute.internal' 'secret_member' "$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Databases/CN=ip-172-31-10-208.us-west-2.compute.internal"

# Certificate: Client
createCertificate 'client' 'ip-172-31-9-18.us-west-2.compute.internal' 'secret_client' "$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Clients/CN=ip-172-31-9-18.us-west-2.compute.internal"
createCertificate 'client' 'ip-172-31-4-146.us-west-2.compute.internal' 'secret_client' "$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Clients/CN=ip-172-31-4-146.us-west-2.compute.internal"
createCertificate 'client' 'ip-172-31-10-167.us-west-2.compute.internal' 'secret_client' "$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Clients/CN=ip-172-31-10-167.us-west-2.compute.internal"

# Certificate: Super User 
superUser="/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Users/CN=ip-172-31-9-18.us-west-2.compute.internal"
createCertificate 'user' 'ip-172-31-9-18.us-west-2.compute.internal' 'secret_user' "$caPassword" $superUser

# create 
userCN=$( openssl x509 -in  ./scripts/certs/user.ip-172-31-9-18.us-west-2.compute.internal.pem  -inform PEM -subject -nameopt RFC2253 -noout | cut -d' ' -f2 )



################################################################################
# Localhost testing 
################################################################################
# Certificates: TLS for all members 
createCertificate 'member' 'server1.arjarapu.net' 'secret_member' "$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Databases/CN=server1.arjarapu.net"
createCertificate 'member' 'server2.arjarapu.net' 'secret_member' "$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Databases/CN=server2.arjarapu.net"
createCertificate 'member' 'server3.arjarapu.net' 'secret_member' "$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Databases/CN=server3.arjarapu.net"

# Certificate: Client
createCertificate 'client' 'client.arjarapu.net' 'secret_client' "$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Clients/CN=client.arjarapu.net"







echo "openssl x509 -in client.pem -inform PEM -subject -nameopt RFC2253 -noout"
echo "use admin; db.getSiblingDB('\$external').runCommand({createUser: $superUser, roles: [{role: 'root', db: 'admin'}]})"
echo "use admin; db.getSiblingDB('\$external').auth({user: $superUser, mechanism: 'MONGODB-X509'})"

echo "Client Certificate Mode * ** "
echo "scp -i ~/.ssh/amazonaws_rsa $caCertsPath/omgr.$serverName.pem  ubuntu@ec2-54-187-50-205.us-west-2.compute.amazonaws.com:/home/ubuntu"
echo "scp -i ~/.ssh/amazonaws_rsa $caCertsPath/rootCA.private.key  ubuntu@ec2-54-187-50-205.us-west-2.compute.amazonaws.com:/home/ubuntu"
echo "scp -i ~/.ssh/amazonaws_rsa $caCertsPath/rootCA.public.crt  ubuntu@ec2-54-202-42-251.us-west-2.compute.amazonaws.com:/home/ubuntu"


echo "scp -i ~/.ssh/amazonaws_rsa $caCertsPath/rootCA.public.crt  ubuntu@ec2-54-149-145-251.us-west-2.compute.amazonaws.com:/home/ubuntu"
echo "scp -i ~/.ssh/amazonaws_rsa $caCertsPath/rootCA.public.crt  ubuntu@ec2-54-186-156-246.us-west-2.compute.amazonaws.com:/home/ubuntu"
echo "scp -i ~/.ssh/amazonaws_rsa $caCertsPath/rootCA.public.crt  ubuntu@ec2-54-202-96-160.us-west-2.compute.amazonaws.com:/home/ubuntu"

echo "
scp -i ~/.ssh/amazonaws_rsa $caCertsPath/rootCA.pem  ubuntu@ec2-54-149-145-251.us-west-2.compute.amazonaws.com:/home/ubuntu
scp -i ~/.ssh/amazonaws_rsa $caCertsPath/rootCA.pem  ubuntu@ec2-54-186-156-246.us-west-2.compute.amazonaws.com:/home/ubuntu
scp -i ~/.ssh/amazonaws_rsa $caCertsPath/rootCA.pem  ubuntu@ec2-54-202-96-160.us-west-2.compute.amazonaws.com:/home/ubuntu
scp -i ~/.ssh/amazonaws_rsa $caCertsPath/rootCA.public.crt  ubuntu@ec2-54-149-145-251.us-west-2.compute.amazonaws.com:/home/ubuntu
scp -i ~/.ssh/amazonaws_rsa $caCertsPath/rootCA.public.crt  ubuntu@ec2-54-186-156-246.us-west-2.compute.amazonaws.com:/home/ubuntu
scp -i ~/.ssh/amazonaws_rsa $caCertsPath/rootCA.public.crt  ubuntu@ec2-54-202-96-160.us-west-2.compute.amazonaws.com:/home/ubuntu

# secret_member
scp -i ~/.ssh/amazonaws_rsa $caCertsPath/member.ip-172-31-13-231.us-west-2.compute.internal.pem  ubuntu@ec2-54-149-145-251.us-west-2.compute.amazonaws.com:/home/ubuntu
scp -i ~/.ssh/amazonaws_rsa $caCertsPath/member.ip-172-31-15-77.us-west-2.compute.internal.pem  ubuntu@ec2-54-186-156-246.us-west-2.compute.amazonaws.com:/home/ubuntu
scp -i ~/.ssh/amazonaws_rsa $caCertsPath/member.ip-172-31-10-208.us-west-2.compute.internal.pem  ubuntu@ec2-54-202-96-160.us-west-2.compute.amazonaws.com:/home/ubuntu

# create automation agent pem key file
caCertsPath='./'
caPassword='secret_ca'
serverRole='automation'
serverName='ip-172-31-13-231.us-west-2.compute.internal'
serverPassword='automation_agent'
subject="/C=US/ST=Texas/L=Austin/O=MongoDB/OU=MMS/CN=$serverPassword"


# create monitoring agent pem key files 
caCertsPath='./'
caPassword='secret_ca'
serverRole='monitoring'
serverName='ip-172-31-10-208.us-west-2.compute.internal'
serverPassword='monitoring_agent'
subject="/C=US/ST=Texas/L=Austin/O=MongoDB/OU=MMS/CN=$serverPassword"



# create backup agent pem key files 
caCertsPath='./'
caPassword='secret_ca'
serverRole='backup'
serverName='ip-172-31-13-231.us-west-2.compute.internal'
serverPassword='backup_agent'
subject="/C=US/ST=Texas/L=Austin/O=MongoDB/OU=MMS/CN=$serverPassword"



openssl genrsa -des3 -passout pass:$serverPassword -out $caCertsPath/$serverRole.$serverName.private.key 4096 
openssl req -new -passin pass:$serverPassword -key $caCertsPath/$serverRole.$serverName.private.key -out $caCertsPath/$serverRole.$serverName.csr -subj $subject
openssl x509 -req -passin pass:$caPassword -in $caCertsPath/$serverRole.$serverName.csr -CA $caCertsPath/rootCA.public.crt -CAkey $caCertsPath/rootCA.private.key -CAcreateserial -out $caCertsPath/$serverRole.$serverName.public.crt -days 365
cat $caCertsPath/$serverRole.$serverName.private.key $caCertsPath/$serverRole.$serverName.public.crt > $caCertsPath/$serverRole.$serverName.pem
openssl verify -CAfile $caCertsPath/rootCA.public.crt $caCertsPath/$serverRole.$serverName.pem 


# upload the files to all three machines
scp -i ~/.ssh/amazonaws_rsa $caCertsPath/automation.ip-172-31-13-231.us-west-2.compute.internal.pem  ubuntu@ec2-54-149-145-251.us-west-2.compute.amazonaws.com:/home/ubuntu
scp -i ~/.ssh/amazonaws_rsa $caCertsPath/backup.ip-172-31-13-231.us-west-2.compute.internal.pem  ubuntu@ec2-54-149-145-251.us-west-2.compute.amazonaws.com:/home/ubuntu
scp -i ~/.ssh/amazonaws_rsa $caCertsPath/monitoring.ip-172-31-10-208.us-west-2.compute.internal.pem  ubuntu@ec2-54-149-145-251.us-west-2.compute.amazonaws.com:/home/ubuntu

scp -i ~/.ssh/amazonaws_rsa $caCertsPath/automation.ip-172-31-13-231.us-west-2.compute.internal.pem  ubuntu@ec2-54-186-156-246.us-west-2.compute.amazonaws.com:/home/ubuntu
scp -i ~/.ssh/amazonaws_rsa $caCertsPath/backup.ip-172-31-13-231.us-west-2.compute.internal.pem  ubuntu@ec2-54-186-156-246.us-west-2.compute.amazonaws.com:/home/ubuntu
scp -i ~/.ssh/amazonaws_rsa $caCertsPath/monitoring.ip-172-31-10-208.us-west-2.compute.internal.pem  ubuntu@ec2-54-186-156-246.us-west-2.compute.amazonaws.com:/home/ubuntu

scp -i ~/.ssh/amazonaws_rsa $caCertsPath/automation.ip-172-31-13-231.us-west-2.compute.internal.pem  ubuntu@ec2-54-202-96-160.us-west-2.compute.amazonaws.com:/home/ubuntu
scp -i ~/.ssh/amazonaws_rsa $caCertsPath/backup.ip-172-31-13-231.us-west-2.compute.internal.pem  ubuntu@ec2-54-202-96-160.us-west-2.compute.amazonaws.com:/home/ubuntu
scp -i ~/.ssh/amazonaws_rsa $caCertsPath/monitoring.ip-172-31-10-208.us-west-2.compute.internal.pem  ubuntu@ec2-54-202-96-160.us-west-2.compute.amazonaws.com:/home/ubuntu


# modify /etc/hosts to have automation as local 
127.0.0.1           automation_agent 
172.31.13.231       backup_agent
172.31.10.208       monitoring_agent

"



createCertificate 'automation' 'ip-172-31-13-231.us-west-2.compute.internal' 'automation-agent' "$caPassword" "/CN=automation-agent/O=MMS"
createCertificate 'backup' 'ip-172-31-13-231.us-west-2.compute.internal' 'backup-agent' "$caPassword"  "/CN=monitoring-agent/O=MMS"
createCertificate 'monitoring' 'ip-172-31-10-208.us-west-2.compute.internal' 'monitoring-agent' "$caPassword"  "/CN=backup-agent/O=MMS"


echo "
scp -i ~/.ssh/amazonaws_rsa $caCertsPath/automation.ip-172-31-13-231.us-west-2.compute.internal.pem  ubuntu@ec2-54-149-145-251.us-west-2.compute.amazonaws.com:/home/ubuntu
scp -i ~/.ssh/amazonaws_rsa $caCertsPath/monitoring.ip-172-31-10-208.us-west-2.compute.internal.pem  ubuntu@ec2-54-202-96-160.us-west-2.compute.amazonaws.com:/home/ubuntu
scp -i ~/.ssh/amazonaws_rsa $caCertsPath/backup.ip-172-31-13-231.us-west-2.compute.internal.pem  ubuntu@ec2-54-149-145-251.us-west-2.compute.amazonaws.com:/home/ubuntu


sudo cp automation.ip-172-31-13-231.us-west-2.compute.internal.pem /opt/automation-agent.pem
sudo cp backup.ip-172-31-13-231.us-west-2.compute.internal.pem /opt/backup-agent.pem
sudo cp monitoring.ip-172-31-10-208.us-west-2.compute.internal.pem /opt/backup-agent.pem
"

echo "sudo mv omgr.$serverName.pem /etc/security/opsmanager.pem"
echo "X-Forwarded-For"

