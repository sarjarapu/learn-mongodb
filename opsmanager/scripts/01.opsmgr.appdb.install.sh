############################################################
# Ops Manager DB: Installing the MongoDB
############################################################
# Run this command on your local box
# i2cssh -Xi=~/.ssh/amazonaws_rsa -c aws_ors_omgr

# Double check the 3 server private name with below before you run these commands 
# Server #1: ip-172-31-2-131.us-west-2.compute.internal
# Server #2: ip-172-31-11-109.us-west-2.compute.internal
# Server #3: ip-172-31-1-41.us-west-2.compute.internal

# Cmd + Shift + I
# inject to run it via aws cli 

if [ 'amzl' == 'rhel' ]
then
# In CentOS 7  is not being resolved properly to 7
releasever=7
sudo tee /etc/yum.repos.d/mongodb-enterprise.repo <<EOF
[mongodb-enterprise]
name=MongoDB Enterprise Repository
baseurl=https://repo.mongodb.com/yum/redhat/$releasever/mongodb-enterprise/3.4/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.4.asc
EOF
else
sudo tee /etc/yum.repos.d/mongodb-enterprise.repo <<EOF
[mongodb-enterprise]
name=MongoDB Enterprise Repository
baseurl=https://repo.mongodb.com/yum/amazon/2013.03/mongodb-enterprise/3.4/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.4.asc
EOF
fi


# Without yum -y upgrade , there is enterprise lib*.so dependency failures I have come across while automating on AMZL 
sudo yum -y upgrade 
sudo yum install -y mongodb-enterprise
sudo mkdir -p /data/appdb/db
sudo chown -R mongod:mongod /data

sudo -u mongod tee /data/appdb/mongod.conf  <<EOF 
systemLog:
   destination: file
   path: /data/appdb/mongod.log
   logAppend: true
storage:
   dbPath: /data/appdb/db
processManagement:
   fork: true
   pidFilePath: /data/appdb/mongod.pid
net:
   port: 27000
replication:
   replSetName: rsAppDB
security:
   authorization: enabled
   keyFile: /data/appdb/keyfile
EOF

sudo -u mongod sh -c "echo secretSaltAppDB | openssl sha1 -sha512  | sed 's/(stdin)= //g' > /data/appdb/keyfile"
sleep 1
sudo -u mongod sh -c 'chmod 400 /data/appdb/keyfile'
sudo -u mongod /usr/bin/mongod --config /data/appdb/mongod.conf 
sleep 2
