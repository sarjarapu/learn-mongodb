#!/bin/sh


############################################################
# Documentation:
#   https://docs.opsmanager.mongodb.com/v3.4/tutorial/install-basic-deployment/
# Tools:
#   brew install https://raw.githubusercontent.com/djui/i2cssh/master/i2cssh.rb
############################################################

awsRegionName="us-west-2"
awsInstanceTagName="ska-ors-demo"
awsSSHUser="ec2-user"
awsPrivateKey="~/.ssh/amazonaws_rsa"
scriptsFolder="./scripts"

############################################################
# Do not modiy anything below this 
############################################################

rm -rf $scriptsFolder
mkdir $scriptsFolder 

############################################################
# EC2 Instance details  
############################################################

# query aws instances by tag name: ska-ors-demo
result=$(aws --region "$awsRegionName" ec2 describe-instances --filters "Name=tag:Name,Values=$awsInstanceTagName")

# Stash the instances, private dns & public dns names into the array variables 
instanceIds=($(echo "$result" | sed -n  's/"InstanceId": "\([^"]*\)",/\1/p' | sed -n 's/[ ]*//p'))
privateDNSNames=($(echo "$result" | sed -n  's/"PrivateDnsName": "\([^"]*\)",/\1/p' | sed -n 's/[ ]*//p' | uniq))
publicDNSNames=($(echo "$result" | sed -n  's/"PublicDnsName": "\([^"]*\)",/\1/p' | sed -n 's/[ ]*//p' | uniq))

# printf '%s\n' "${instanceIds[@]}"
# printf '%s\n' "${privateDNSNames[@]}"
# printf '%s\n' "${publicDNSNames[@]}"

############################################################
# Install a Basic Production Deployment on RHEL or Amazon Linux
# https://docs.opsmanager.mongodb.com/v3.4/tutorial/install-basic-deployment/
############################################################

# Setup: 
# Servers:  server-1    server-2    server-3
#   OpsDB:  primary     secondary   secondary
#   BkpDB:  secondary   primary     secondary
#  OpsWeb:  http        http
#  Daemon:              BackupD

############################################################
# Update your i2csshrc with instance public IPs  
############################################################

tee "$scriptsFolder/.i2csshrc" <<EOF
version: 2
iterm2: true
clusters:
  aws_ors_omgr:
    login: $awsSSHUser
    hosts:
      - ${publicDNSNames[0]}
      - ${publicDNSNames[1]}
      - ${publicDNSNames[2]}
  aws_ors_bkdb:
    login: $awsSSHUser
    hosts:
      - ${publicDNSNames[3]}
      - ${publicDNSNames[4]}
      - ${publicDNSNames[5]}
  aws_ors_mongo:
    login: $awsSSHUser
    hosts:
      - ${publicDNSNames[6]}
      - ${publicDNSNames[7]}
      - ${publicDNSNames[8]}
EOF

tee "$scriptsFolder/01.install.ops.manager.sh" <<INSOPSMGR

############################################################
# Ops Manager DB: Installing the MongoDB
############################################################
i2cssh -Xi=$awsPrivateKey -c aws_ors_omgr

# Cmd + Shift + I
# inject to run it via aws cli 

sudo yum -y upgrade 
sudo tee /etc/yum.repos.d/mongodb-enterprise.repo <<EOF
[mongodb-enterprise]
name=MongoDB Enterprise Repository
baseurl=https://repo.mongodb.com/yum/amazon/2013.03/mongodb-enterprise/3.4/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.4.asc
EOF

sudo yum install -y mongodb-enterprise
sudo mkdir -p /data/appdb/db
sudo chown mongod:mongod /data /data/appdb /data/appdb/db

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
#security:
#   authorization: enabled
#   keyFile: /data/appdb/keyfile
EOF

sudo -u mongod sh -c "echo secretsaltAppDB | openssl sha1 -sha512  | sed 's/(stdin)= //g' > /data/appdb/keyfile"
sudo -u mongod sh -c "chmod 400 /data/appdb/keyfile"
sudo -u mongod /usr/bin/mongod --config /data/appdb/mongod.conf 
sleep 2


############################################################
# Ops Manager DB: Configure MongoDB ReplicaSet
# Run only on Server #1: ec2-54-213-251-22.us-west-2.compute.amazonaws.com / ip-172-31-24-226.us-west-2.compute.internal
############################################################

mongo --port 27000 <<EOF
rs.initiate({_id: "rsOplogStore", "members" : [{ "_id" : 0, "host" : "ip-172-31-3-243.us-west-2.compute.internal:27000"}]})
EOF
sleep 10 


mongo --port 27000 <<EOF
use admin
db.createUser({user: 'superuser', pwd: 'secret', roles: ['root']})
rs.add('ip-172-31-12-99.us-west-2.compute.internal:27000')
rs.add('ip-172-31-6-222.us-west-2.compute.internal:27000')
EOF

mongo --port 27000 <<EOF
rs.initiate({_id: "rsAppDB", "members" : [{ "_id" : 0, "host" : "${privateDNSNames[0]}:27000"}]})
EOF
sleep 10 
mongo --port 27000 <<EOF
rs.add('${privateDNSNames[1]}:27000')
rs.add('${privateDNSNames[2]}:27000')
EOF



# Confirm primary, arbiter, secondary by running on all servers 
# Cmd + Shift + I
# mongo --port 27000 & exit 

mongo admin --port 27000 --eval 'db.shutdownServer({force: true})'
sleep 2
sudo -u mongod sed -i  's/#//g' /data/appdb/mongod.conf
sudo -u mongod /usr/bin/mongod --config /data/appdb/mongod.conf 
sleep 10


############################################################
# Ops Manager DB: Create the init.d startup scripts 
############################################################

sudo -u mongod sed  's#/etc/mongod.conf#/data/appdb/mongod.conf#g' /etc/init.d/mongod > /tmp/mongod-appdb 
sudo mv /tmp/mongod-appdb /etc/init.d/mongod-appdb
sudo chown mongod:mongod /etc/init.d/mongod-appdb
sudo chmod 755 /etc/init.d/mongod-appdb
sudo chkconfig --add mongod-appdb 
sudo chkconfig mongod-appdb on
sudo ln -s /etc/rc.d/init.d/mongod-appdb /etc/rc.d/rc3.d/mongod-appdb

sudo cat /etc/rc.d/rc3.d/mongod-appdb


sudo -u mongod sed  's#/data/appdb/mongod.conf#/data/oplogstore/mongod.conf#g' /etc/init.d/mongod-appdb > /tmp/mongod-oplogstore
sudo mv /tmp/mongod-oplogstore /etc/init.d/mongod-oplogstore
sudo chown mongod:mongod /etc/init.d/mongod-oplogstore
sudo chmod 755 /etc/init.d/mongod-oplogstore
sudo chkconfig --add mongod-oplogstore 
sudo chkconfig mongod-oplogstore on


# sudo curl -o /etc/init.d/mongod-appdb -L https://git.io/vXlx4
# sudo rm /etc/init.d/mongod



############################################################
# Backup DB: Installing the MongoDB
############################################################
sudo mkdir -p /data/oplogstore/db
sudo chown mongod:mongod /data /data/oplogstore /data/oplogstore/db

sudo -u mongod tee /data/oplogstore/mongod.conf  <<EOF 
systemLog:
   destination: file
   path: /data/oplogstore/mongod.log
   logAppend: true
storage:
   dbPath: /data/oplogstore/db
processManagement:
   fork: true
   pidFilePath: /data/oplogstore/mongod.pid
net:
   port: 27001
replication:
   replSetName: rsOplogStore
#security:
#   authorization: enabled
#   keyFile: /data/oplogstore/keyfile
EOF

sudo -u mongod sh -c "echo secretsaltOplogStore | openssl sha1 -sha512  | sed 's/(stdin)= //g' > /data/oplogstore/keyfile"
sudo -u mongod sh -c "chmod 400 /data/oplogstore/keyfile"
sudo -u mongod /usr/bin/mongod --config /data/oplogstore/mongod.conf 
sleep 2


############################################################
# Backup DB: Create the init.d startup scripts 
############################################################

sudo -u mongod sed  's#/etc/mongod.conf#/data/oplogstore/mongod.conf#g' /etc/init.d/mongod > /tmp/mongod-oplogstore 
sudo mv /tmp/mongod-oplogstore /etc/init.d/mongod-oplogstore
sudo chown mongod:mongod /etc/init.d/mongod-oplogstore
sudo chmod 755 /etc/init.d/mongod-oplogstore
# sudo update-rc.d mongod-oplogstore defaults
sudo chkconfig mongod-oplogstore on

# sudo curl -o /etc/init.d/mongod-oplogstore -L https://git.io/vXlx4
# sudo rm /etc/init.d/mongod


# sudo mkdir -p /data/backup
# sudo chown mongod:mongod -R /data
# sudo chmod 755 -R /data

############################################################
# Backup DB: Configure MongoDB ReplicaSet
# Run only on Server #3: ec2-54-191-2-174.us-west-2.compute.amazonaws.com / ip-172-31-23-245.us-west-2.compute.internal:27001
############################################################

# ip-172-31-3-243.us-west-2.compute.internal:27001,ip-172-31-12-99.us-west-2.compute.internal:27001,ip-172-31-6-222.us-west-2.compute.internal:27001

mongo --port 27001 <<EOF
rs.initiate({_id: "rsOplogStore", "members" : [{ "_id" : 0, "host" : "ip-172-31-6-222.us-west-2.compute.internal:27001"}]})
EOF
sleep 10 

mongo --port 27001 <<EOF
db.createUser({user: 'superuser', pwd: 'secret', roles: ['root']});
rs.add('ip-172-31-12-99.us-west-2.compute.internal:27001')
rs.add('ip-172-31-3-243.us-west-2.compute.internal:27001')
EOF
sleep 10 

mongo --port 27001 <<EOF
rs.initiate({_id: "rsOplogStore", "members" : [{ "_id" : 0, "host" : "${privateDNSNames[5]}:27001"}]})
EOF
sleep 10 

mongo --port 27001 <<EOF
rs.add('${privateDNSNames[4]}:27001')
rs.add('${privateDNSNames[3]}:27001')
EOF



# Confirm primary, arbiter, secondary by running on all servers 
# Cmd + Shift + I
# mongo --port 27001 & exit 


mongo admin --port 27001 --eval 'db.shutdownServer({force: true})'
sleep 2
sudo -u mongod sed -i  's/#//g' /data/oplogstore/mongod.conf
sudo -u mongod /usr/bin/mongod --config /data/oplogstore/mongod.conf 
sleep 10


############################################################
# Ops Manager: Install HTTP Service
# Install it on server-1 & server-3
# Server #1: ec2-54-213-251-22.us-west-2.compute.amazonaws.com / ip-172-31-24-226.us-west-2.compute.internal
# Server #3: ec2-54-191-2-174.us-west-2.compute.amazonaws.com / ip-172-31-23-245.us-west-2.compute.internal
# https://docs.opsmanager.mongodb.com/current/tutorial/install-on-prem-with-rpm-packages/
############################################################
wget https://downloads.mongodb.com/on-prem-mms/rpm/mongodb-mms-3.4.1.385-1.x86_64.rpm
sudo rpm -ivh mongodb-mms-3.4.1.385-1.x86_64.rpm
sudo vi /opt/mongodb/mms/conf/conf-mms.properties

# Goto this line and replace connection string 
# mongo.mongoUri=mongodb://127.0.0.1:27017/?maxPoolSize=150
# mongodb://superuser:secret@ip-172-31-3-243.us-west-2.compute.internal:27000,ip-172-31-12-99.us-west-2.compute.internal:27000,ip-172-31-6-222.us-west-2.compute.internal:27000/?authSource=admin&replicaSet=rsAppDB&maxPoolSize=150
# mongo.replicaSet=rsAppDB

############################################################
# Ops Manager: Start only one of the Server #1
# Server #1: ec2-54-213-251-22.us-west-2.compute.amazonaws.com / ip-172-31-24-226.us-west-2.compute.internal
# Notes: Will take 2 mins. 
############################################################
sudo service mongodb-mms start


############################################################
# Ops Manager: Conigure the Ops Manager via UI
############################################################
http://ec2-54-213-251-22.us-west-2.compute.amazonaws.com:8080
# shyam.arjarapu@10gen.com ORS smtp.gmail.com


############################################################
# Ops Manager: Copy /etc/mongodb-mms/gen.key from Server #1 to #3
# Copy gen.key, start mms, create backup deamon folder
############################################################
scp -i ~/.ssh/amazonaws_rsa ~/.ssh/amazonaws_rsa  $awsSSHUser@ec2-54-149-142-159.us-west-2.compute.amazonaws.com:/home/$awsSSHUser
sudo scp -i amazonaws_rsa /etc/mongodb-mms/gen.key  $awsSSHUser@ip-172-31-12-99.us-west-2.compute.internal:/home/$awsSSHUser
# sudo scp -i amazonaws_rsa /etc/mongodb-mms/gen.key  $awsSSHUser@ip-172-31-6-222.us-west-2.compute.internal:/home/$awsSSHUser

# Server #3: ec2-54-191-2-174.us-west-2.compute.amazonaws.com / ip-172-31-23-245.us-west-2.compute.internal
sudo mv gen.key /etc/mongodb-mms/gen.key
sudo chown mongodb-mms:mongodb-mms /etc/mongodb-mms/gen.key
sudo service mongodb-mms start



############################################################
# Backup Daemon: On Server #3 create headdb folder
############################################################
sudo mkdir -p /backup/headdb
sudo chown mongodb-mms:mongodb-mms /backup /backup/headdb

# Ops Manager UI: Backup > configure the backup module
# /backup/headdb
# enable daemon


############################################################
# Filesystem Store: On Ops Manager HTTP Server # 1 & #3
############################################################
sudo mkdir -p /backup/filesystemStore
sudo chown mongodb-mms:mongodb-mms /backup /backup/filesystemStore

# superuser:secret
# mongodb://superuser:secret@
# ip-172-31-3-243.us-west-2.compute.internal:27001,ip-172-31-12-99.us-west-2.compute.internal:27001,ip-172-31-6-222.us-west-2.compute.internal:27001
# /?authSource=admin&replicaSet=rsOplogStore&maxPoolSize=150

###############################################################
# Install Automation Agents
###############################################################

i2cssh -Xi=~/.ssh/amazonaws_rsa -c aws_ors_mongo
sudo yum -y upgrade 

curl -OL http://ec2-54-149-142-159.us-west-2.compute.amazonaws.com:8080/download/agent/automation/mongodb-mms-automation-agent-manager-3.2.8.1942-1.x86_64.rpm
sudo rpm -U mongodb-mms-automation-agent-manager-3.2.8.1942-1.x86_64.rpm

sudo cp /etc/mongodb-mms/automation-agent.config /tmp/automation-agent.orig.config
sudo sed "s/mmsGroupId=/mmsGroupId=588a07c22119e9796720ace5/g" /etc/mongodb-mms/automation-agent.config | \
    sed "s/mmsApiKey=/mmsApiKey=3136703d14c1919ee176180c2b5d7157/g" | \
    sed "s/mmsBaseUrl=/mmsBaseUrl=http:\/\/ec2-54-149-142-159.us-west-2.compute.amazonaws.com:8080/g" | \
    tee /tmp/automation-agent.config
sudo -u mongod cp /tmp/automation-agent.config /etc/mongodb-mms/automation-agent.config
sudo cat /etc/mongodb-mms/automation-agent.config

sudo mkdir -p /data
sudo chown mongod:mongod /data
sudo service mongodb-mms-automation-agent start

###############################################################
# Pool: Install Automation Agents
###############################################################

i2cssh -Xi=~/.ssh/amazonaws_rsa -c aws_ors_pool
sudo yum -y upgrade 

curl -OL http://ec2-54-149-142-159.us-west-2.compute.amazonaws.com:8080/download/agent/automation/mongodb-mms-automation-agent-manager-3.2.8.1942-1.x86_64.rpm
sudo rpm -U mongodb-mms-automation-agent-manager-3.2.8.1942-1.x86_64.rpm

sudo cp /etc/mongodb-mms/automation-agent.config /tmp/automation-agent.orig.config
sudo sed "s/serverPoolKey=/serverPoolKey=4e324700df392529b115cb2b992efb14/g" /etc/mongodb-mms/automation-agent.config | \
    sed "s/mmsBaseUrl=/mmsBaseUrl=http:\/\/ec2-54-149-142-159.us-west-2.compute.amazonaws.com:8080/g" | \
    tee /tmp/automation-agent.config
sudo -u mongod cp /tmp/automation-agent.config /etc/mongodb-mms/automation-agent.config
sudo cat /etc/mongodb-mms/automation-agent.config


# Use 3 MEDIUM NY IL OR ad 2 LARGE NY IL. Have LARGE IL agent stop 
sudo -u mongod tee /etc/mongodb-mms/server-pool.properties <<EOF 
Datacenter=US-EAST-NY
Size=Medium_CPU4_RAM16GB
EOF

sudo -u mongod vi /etc/mongodb-mms/server-pool.properties 

sudo mkdir -p /data
sudo chown mongod:mongod /data
sudo service mongodb-mms-automation-agent start

# regex  ip-172-31-13-163|ip-172-31-6-73|ip-172-31-8-94

# Server Pool - Feature requests
# Pending requests .. how to know which instance is reserved and whats not for your request id 
# also servers listing shows the servers are bound or reserved but doesn't show request.
# I think we need little more information & ability to jump from one screen to other otherwise
# it might become difficult to figureout what servers needs to be provisioned to fullfil request  

# also we request for a pool of say 3 servers across IL, NY, OR . servers are provisioned if available 
# which is great however, the main intension of we requesting multiple is to create replicaset or 
# shared cluster with it. there is no easy way to create replicaset otherthan using their machine names 
# in the regex. may be we should let the requests be tagged with pool name to quickly find the servers 
# and use them while creating replicasets / clusters and provide an option to create replicaset soon
# after we show the servers are provisioned for your request. May be even let them drag drop mongod, 
# config and mongos. Also i do not recall seing a message something like your request id# xyz once 
# those servers are created and or pending. So that user could follow up with other admins on request id 


###############################################################
# Creating an existing MongoDB for Applications 
###############################################################


sudo yum -y upgrade 

cat <<EXT | sudo tee /etc/yum.repos.d/mongodb-org-2.6.repo
[mongodb-org-2.6]
name=MongoDB 2.6 Repository
baseurl=http://downloads-distro.mongodb.org/repo/redhat/os/x86_64/
gpgcheck=0
enabled=1
EXT
sudo yum install -y mongodb-org-2.6.8


sudo mkdir -p /data/db
sudo chown mongod:mongod /data /data/db

sudo tee /etc/mongod.conf  <<EOF 
logpath=/data/mongod.log
logappend=true
fork=true
dbpath=/data/db
pidfilepath=/data/mongod.pid
#auth=true
replSet=progresoReplSet
keyFile=/data/keyfile
EOF
sudo chown mongod:mongod /etc/mongod.conf

sudo -u mongod sh -c "echo secretsaltprogresoReplSet | openssl sha1 -sha512  | sed 's/(stdin)= //g' > /data/keyfile"
sudo -u mongod sh -c "chmod 400 /data/keyfile"
sudo -u mongod /usr/bin/mongod --config /etc/mongod.conf 
sleep 2

# ip-172-31-7-71.us-west-2.compute.internal
# ip-172-31-15-124.us-west-2.compute.internal
# ip-172-31-9-137.us-west-2.compute.internal

mongo --port 27017
rs.initiate()
use admin

rs.add('ip-172-31-15-124.us-west-2.compute.internal:27017')
rs.add('ip-172-31-9-137.us-west-2.compute.internal:27017')
EOF


# Populate dummy data 
for(var i = 0; i < 100000; i++) db.data.insert({text: Math.random().toString(36)})



# While importing the existing deployment, make sure you enable authentication and give the user/pwd 
# Login as superuse & create the below user 
use admin 
db.createUser({user: 'mms-automation', pwd: 'secret', roles: ['clusterAdmin', 'dbAdminAnyDatabase', 'readWriteAnyDatabase', 'restore', 'userAdminAnyDatabase']})

# Gotcha: 
# use /data/db for database never do /data 
# This operation requires that the parent directory of the data directory be writeable by the Automation Agent user, as during the conversion process the Automation Agent will create a temporary backup directory alongside the data directory. Depending on the size of the data, changing the storage engine may be a very long running operation.

































############################################################
# Replace these IP addesses with your current set 
############################################################
# opsmgr set
# ip-172-31-14-242.us-west-2.compute.internal
# ip-172-31-4-99.us-west-2.compute.internal
# ip-172-31-12-151.us-west-2.compute.internal
# ec2-54-202-168-181.us-west-2.compute.amazonaws.com
# ec2-54-202-190-254.us-west-2.compute.amazonaws.com
# ec2-54-213-1-105.us-west-2.compute.amazonaws.com

# mongdb AppDB
# ec2-54-244-159-69.us-west-2.compute.amazonaws.com
# ec2-54-244-161-108.us-west-2.compute.amazonaws.com
# ec2-54-244-161-117.us-west-2.compute.amazonaws.com

# mmsGroupId=588132557f3f5b2190ad6e23
# mmsApiKey=a82c9e18ed53e9846396c16da4fe97e7
# mmsBaseUrl=http://ec2-54-202-110-174.us-west-2.compute.amazonaws.com:8080
# Load balancer: http://ec2-54-202-110-174.us-west-2.compute.amazonaws.com:8080
# opsmgr 1: http://ec2-54-202-168-181.us-west-2.compute.amazonaws.com:8080
# mongos ec2-54-202-233-130.us-west-2.compute.amazonaws.com

# Twilio SID: AC5ad073b032ef6c9befa21638878e458a
# Twilio Auth: 4e643b1cecdb98636071c381bc4d353d

# i2cssh -Xi=~/.ssh/amazonaws_rsa -c aws_ors_omgr
# i2cssh -Xi=~/.ssh/amazonaws_rsa -c aws_ors_mongo
# openssl rand 24 > /<keyPath>/gen.key

# filesystem stores & head databases

###############################################################
# Generating the load 
###############################################################

# ip-172-31-0-137.us-west-2.compute.internal
scp -i ~/.ssh/amazonaws_rsa /Users/shyamarjarapu/Code/work/mongodb/git-hub/poc-driver/bin/POCDriver.jar  $awsSSHUser@ec2-54-244-159-69.us-west-2.compute.amazonaws.com:/home/$awsSSHUser
scp -i ~/.ssh/amazonaws_rsa /Users/shyamarjarapu/Code/work/mongodb/git-hub/poc-driver/bin/POCDriver.jar  $awsSSHUser@ec2-54-244-161-108.us-west-2.compute.amazonaws.com:/home/$awsSSHUser
scp -i ~/.ssh/amazonaws_rsa /Users/shyamarjarapu/Code/work/mongodb/git-hub/poc-driver/bin/POCDriver.jar  $awsSSHUser@ec2-54-244-161-117.us-west-2.compute.amazonaws.com:/home/$awsSSHUser
java -jar POCDriver.jar -i 20 -k 20 -b 10 -u 20 -c "mongodb://root:secret@ec2-54-244-159-69.us-west-2.compute.amazonaws.com:27000/?authSource=admin&replicaSet=rsProd-AppDB"
java -jar POCDriver.jar -i 60 -k 30 -b 10 -c "mongodb://root:secret@ec2-54-244-159-69.us-west-2.compute.amazonaws.com:27000/?authSource=admin&replicaSet=rsProd-AppDB"





###############################################################
# Install Automation Agents
###############################################################

i2cssh -Xi=~/.ssh/amazonaws_rsa -c aws_ors_mongo
sudo yum -y upgrade 

curl -OL http://ec2-54-202-110-174.us-west-2.compute.amazonaws.com:8080/download/agent/automation/mongodb-mms-automation-agent-manager-3.2.8.1942-1.x86_64.rpm

# Confirm the size is same across all servers
# ls -ltr mongodb-mms-automation-agent-manager-3.2.8.1942-1.x86_64.rpm  | awk '{print $5}'

sudo rpm -U mongodb-mms-automation-agent-manager-3.2.8.1942-1.x86_64.rpm
# sudo service mongodb-mms-automation-agent stop
# sudo rpm -e mongodb-mms-automation-agent-manager
# sudo rm /etc/mongodb-mms/automation-agent.config.rpmsave
# sudo cat /etc/mongodb-mms/automation-agent.config


sudo cp /etc/mongodb-mms/automation-agent.config /tmp/automation-agent.orig.config
sudo sed "s/mmsGroupId=/mmsGroupId=588132557f3f5b2190ad6e23/g" /etc/mongodb-mms/automation-agent.config | \
    sed "s/mmsApiKey=/mmsApiKey=a82c9e18ed53e9846396c16da4fe97e7/g" | \
    sed "s/mmsBaseUrl=/mmsBaseUrl=http:\/\/ec2-54-202-110-174.us-west-2.compute.amazonaws.com:8080/g" | \
    tee /tmp/automation-agent.config
sudo cp /tmp/automation-agent.config /etc/mongodb-mms/automation-agent.config
sudo cat /etc/mongodb-mms/automation-agent.config

sudo mkdir -p /data
sudo chown mongod:mongod /data
sudo service mongodb-mms-automation-agent start





# Configuring the backup daemon & headdb

# Find out where the backup daemon is running & ssh there 
sudo mkdir -p /backup/headdb
sudo chown -R mongodb-mms:mongodb-mms /backup/headdb









# Uninstall MongoDB
sudo service mongod stop
sudo yum -y erase $(rpm -qa | grep mongodb-enterprise)
sudo rm -rf /var/log/mongodb
sudo rm -rf /var/lib/mongo

# Connecting to MongoS
mongo ec2-54-202-233-130.us-west-2.compute.amazonaws.com

# Run on Laptop Uploading the jar file
# scp -i ~/.ssh/amazonaws_rsa ~/Code/work/mongodb/git-hub/poc-driver/bin/POCDriver.jar  $awsSSHUser@ec2-54-187-204-32.us-west-2.compute.amazonaws.com:/home/$awsSSHUser

# Download jar file on servers
# scp -i ~/.ssh/amazonaws_rsa ~/Code/work/mongodb/git-hub/poc-driver/bin/POCDriver.jar  $awsSSHUser@ec2-54-187-204-32.us-west-2.compute.amazonaws.com:/home/$awsSSHUser
wget --no-check-certificate 'https://docs.google.com/uc?export=download&id=0B4KRgMp8k0BieHpHQWZkT1g5Y1k' -O POCDriver.jar


ssh -i ~/.ssh/amazonaws_rsa $awsSSHUser@ec2-54-187-28-219.us-west-2.compute.amazonaws.com
java -jar POCDriver.jar -i 20 -k 20 -b 10 -u 20 -c "mongodb://ip-172-31-33-163.us-west-2.compute.internal:27017/"

java -jar POCDriver.jar -i 20 -k 20 -b 10 -u 20 -c "mongodb://ip-172-31-33-164.us-west-2.compute.internal:27017/"


# java -jar POCDriver.jar -i 20 -k 20 -b 10 -u 20 -c "mongodb://ip-172-31-9-250.us-west-2.compute.internal:27017/"
# java -jar POCDriver.jar -i 20 -k 20 -b 10 -u 20 -c "mongodb://ip-172-31-9-251.us-west-2.compute.internal:27017/"
# state should be: writes is not an empty list

https://docs.opsmanager.mongodb.com/v2.0/tutorial/configure-monitoring-munin-node/

sudo yum install -y munin-node
sudo service munin-node start

sudo mkdir -p /backup/headdb
sudo chown -R mongodb-mms:mongodb-mms /backup/headdb


###############################################################
# Install Backup Agent 
# link https://docs.opsmanager.mongodb.com/v2.0/tutorial/install-backup-agent-with-rpm-package/
###############################################################

curl -OL http://ec2-54-202-110-174.us-west-2.compute.amazonaws.com:8080/download/agent/backup/mongodb-mms-backup-agent-latest.x86_64.rpm
sudo rpm -U mongodb-mms-backup-agent-latest.x86_64.rpm

sudo cp /etc/mongodb-mms/backup-agent.config /tmp/backup-agent.orig.config
sudo sed "s/mmsGroupId=/mmsGroupId=588132557f3f5b2190ad6e23/g" /etc/mongodb-mms/backup-agent.config | \
    sed "s/mmsApiKey=/mmsApiKey=a82c9e18ed53e9846396c16da4fe97e7/g" | \
    sed "s/mmsBaseUrl=/mmsBaseUrl=http:\/\/ec2-54-202-110-174.us-west-2.compute.amazonaws.com:8080/g" | \
    tee /tmp/backup-agent.config
sudo cp /tmp/backup-agent.config /etc/mongodb-mms/backup-agent.config
sudo cat /etc/mongodb-mms/backup-agent.config
sudo service mongodb-mms-backup-agent start





# Questions 
# https://mongodb--c.na7.visual.force.com/apex/Console_CaseView?id=500A000000W8ENaIAN&sfdc.override=1
# https://support.mongodb.com/case/00421662

How many replica sets and sharded clusters will be monitored/managed by Ops Manager?
24 replica sets per environment

How many replica sets and sharded clusters will be backed up by Ops Manager?
24

How much HA/redundancy do you want in the deployment? A typical production deployment has three Ops Manager Application database servers and another three Blockstore database servers for Ops Manager Backup (if used).
Backups (if applicable):
Will depend on requirements, assume recommendation

Would you prefer to keep your backups in Blockstore or Filesystem Format? Please see this page for a description of both options.
Haven't decided. 
>>>>>  Filesystem

For each replica set and shard, what is the:
Oplog/day per replica set (GB) ~5mb
>>>>>> is that / hr??
File size per replica set (GB)250GB
How compressible is the data? Is it text, videos, binaries?
text


What is your expected growth over the next 6, 12, and 18 months? If it is somewhat difficult to procure hardware at your organization, we recommend sizing up for more than you will need.
when we add sharing we should be able to reduce.
>>>>>>> ?

Retention:
What is the Point In Time Restore requirement in hours? (default is 48)
4hrs

How frequently do you want your snapshots taken? (default is 24 hrs, other options are 6, 8, and 12)?
2hrs
The lowest time between snapshots that we support is 6 hours. There are a lot of moving parts involved in collecting a snapshot so this is intended to reduce the amount of background load on the Ops Manager components. The oplog of each primary node is streamed to the Backup Daemons between each snapshot, this provides a point in time restore option to any point between each snapshot for a standard deployment. For sharded clusters, checkpoints can be collected at intervals of 15, 30 or 60 minutes to give you an extra restore point between snapshots.

For the purpose of this calculation I will select 6 hours for the snapshot frequency, the oplog stream can be used for point in time restores between the snapshots. When you add sharding you can then create checkpoints as discussed above.

How many of these snapshots should be kept? (default is 2, so spanning the last 48 hours)
1
As we need to collect a snapshot once every 6 hours, we would recommend a minimum of 5 of these snapshots are kept. This will allow you a point in time recovery of 24 hours. If you wish for a greater point in time recovery option this will need to be increased, however as you have specified only 4 hours for point in time recovery I believe 24 hours will be sufficient.



What is the required number of Daily, Weekly, and Monthly snapshots to keep? (default is 5 which includes weekly snapshots for 2 weeks, and monthly snapshots for 1 month)
1 week

How long would you like to store the oldest snapshot? We are able to store information for up to 13 months, however, the retention period for snapshots can dramatically affect your total data size.
3 weeks
The minimum we would recommend here is 4 weeks, please let me know if this is suitable.


Do you desire high availability, a minimal configuration, or something in between?
high availability


I Plan on having 4 Ops managers (1 in each datacenter). Depending on the Datacenter they are in the will have a minimum of 3 replicas and a maximum of 6.
File System Storage Snapshots seems most likely
6hrs will have to do.
Recommendation of 5 is fine.
4 weeks is fine as well.



# Can I use LDAP?	Yes but this must be set up BEFORE/during installation. It cannot be configured or added later.
https://docs.opsmanager.mongodb.com/v3.4/tutorial/install-basic-deployment/



1.2 Environment
● Amazon Web Services ○ EC2
○ S3
○ SES
○ Independent VPCs
● Debian 14.04
● EBS with provisioned IOPs

MongoDB Version, Java Driver Version, ReplicaSet, Servers - name, disk, cpu, ram, 
Data Centers, applications and how they are connected / interrelated 
thp
ulimits
init.d


blpi241.bhdc.att.com, Secondary, (/opt/app/p3tda3c1/data), 296GB (101GB used), 4 processors Intel(R) Xeon(R) CPU E5-2630L 0 @2.00GHz , 64 GB


https://docs.opsmanager.mongodb.com/current/core/deployments/
Only the Backup Daemon needs to communicate with the head databases. As such, their net.bindIp value is 127.0.0.1 to prevent external communication. net.bindIp specifies the IP address that mongod and mongos listens to for connections coming from applications.

https://docs.mongodb.com/manual/administration/production-checklist-operations/
hostname
uname -a
lscpu 
lsblk
cat /proc/meminfo
sudo fdisk -l
mongo --port 27017 --eval 'rs.status()'
mongo --port 27017 --eval 'db.getSiblingDB("BirstDB").stats()'
mongo --port 27017 --eval 'db.serverStatus()'
sudo -u mongod sh -c "ulimit -a"
numactl --hardware
sysctl net.ipv4.tcp_keepalive_time
sudo sysctl vm.zone_reclaim_mode

# can you run it on the device where your mongod is installing 
# sudo blockdev --getra /dev/xvda



sudo mv /etc/rc.d/init.d/mongod /etc/rc.d/init.d/mongod-appdb
sudo cp /etc/rc.d/init.d/mongod-appdb /etc/rc.d/init.d/mongod-oplogstore


sudo -u mongod sh -c "sed -i  's#/etc/mongod.conf#/data/appdb/mongod.conf#g' /etc/rc.d/init.d/mongod-appdb"
sudo -u mongod sed -i  's#/etc/mongod.conf#/data/oplogstore/mongod.conf#g' /etc/rc.d/init.d/mongod-oplogstore

sudo chown mongod -R /data
sudo chown mongod -R  /var/log/mongodb-mms-automation
sudo chown mongod -R  /var/lib/mongodb-mms-automation

nohup sudo -u mongod ./mongodb-mms-automation-agent --config=local.config >> /var/log/mongodb-mms-automation/automation-agent.log 2>&1 &



Question#: 
Q: I got only daemon running .. not sure where does it see the other 2 from 
Notes: 1 Backup Daemon(s) configured for use. A total of 3 Backup Daemon(s) exist. 

Q: Take snapshots for every 24 hours  & save for 5 days. Client is looking for 24 hrs + 7 days but "Daily snapshot" gets enabled only if other than 24 hrs 

Q: Once onboarded to Ops Mgr & Automation. What all operations they can or cannot do directly on a mongodb server ? 


========================
Status Update 
========================
. Done: Install Ops Manager AppDB as PSS replicaset 
. Done: Install Ops Manager Oplog as PSS replicaset
. Done: Install Ops Manager HTTP Service 
. Done: Registering Admin User & Basic configurations on Ops Manager HTTP Service 
. Done: Waiting for team to come back from their meeting 
. Done: Install Automation Agent on existing QA replicaset
. Done: Import on existing QA MongoDB v2.6 replicaset 
. Done: Create headdb & blockstore map directories on server running Backup Daemon + chown mongdb-mms 
. Done: Configure Backup for QA replicaSet 
. Done: Wait for init sync to complete 
. Done: Populate some dummy data in collection 
. Done: Restore the snapshot to QA replicaSet and confirm no dummy data exists 
. Done: for tomorrow if time permits 
. Done: Upgrade 2.6 MongoDB to MongoDB 3.0.* MMAP
. Skipped: Run their build server with automated tests. Skipped because of 5 hr run time 
. Done: Upgrade 3.0 MongoDB MMAP to MongoDB 3.2 MMAP 
. Done: Upgrade 3.2 MongoDB MMAP to MongoDB 3.2 WT 



cp /etc/security/limits.conf /etc/security/limits.d/99-mongodb-nproc.conf


wget -O /etc/init.d/disable-transparent-hugepages http://git.io/vlHzS
sudo chmod 755 /etc/init.d/disable-transparent-hugepages
chkconfig disable-transparent-hugepages on



Questions asked

can I have a user just for the specific secondary 
how 