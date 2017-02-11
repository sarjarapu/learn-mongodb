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
scp -i ~/.ssh/amazonaws_rsa /Users/shyamarjarapu/Code/work/mongodb/git-hub/poc-driver/bin/POCDriver.jar  ec2-user@ec2-54-244-159-69.us-west-2.compute.amazonaws.com:/home/ec2-user
scp -i ~/.ssh/amazonaws_rsa /Users/shyamarjarapu/Code/work/mongodb/git-hub/poc-driver/bin/POCDriver.jar  ec2-user@ec2-54-244-161-108.us-west-2.compute.amazonaws.com:/home/ec2-user
scp -i ~/.ssh/amazonaws_rsa /Users/shyamarjarapu/Code/work/mongodb/git-hub/poc-driver/bin/POCDriver.jar  ec2-user@ec2-54-244-161-117.us-west-2.compute.amazonaws.com:/home/ec2-user
java -jar POCDriver.jar -i 20 -k 20 -b 10 -u 20 -c "mongodb://root:secret@ec2-54-244-159-69.us-west-2.compute.amazonaws.com:27000/?authSource=admin&replicaSet=rsProd-AppDB"
java -jar POCDriver.jar -i 60 -k 30 -b 10 -c "mongodb://root:secret@ec2-54-244-159-69.us-west-2.compute.amazonaws.com:27000/?authSource=admin&replicaSet=rsProd-AppDB"





###############################################################
# Install Automation Agents
###############################################################

i2cssh -Xi=~/.ssh/amazonaws_rsa -c aws_ors_mongo
sudo yum -y upgrade 

curl -OL http://ec2-54-202-110-174.us-west-2.compute.amazonaws.com:8080/download/agent/automation/mongodb-mms-automation-agent-manager-3.2.8.1942-1.x86_64.rpm

# Confirm the size is same across all servers
# ls -ltr mongodb-mms-automation-agent-manager-3.2.8.1942-1.x86_64.rpm  | awk '{print }'

sudo rpm -U mongodb-mms-automation-agent-manager-3.2.8.1942-1.x86_64.rpm
# sudo service mongodb-mms-automation-agent stop
# sudo rpm -e mongodb-mms-automation-agent-manager
# sudo rm /etc/mongodb-mms/automation-agent.config.rpmsave
# sudo cat /etc/mongodb-mms/automation-agent.config


sudo cp /etc/mongodb-mms/automation-agent.config /tmp/automation-agent.orig.config
sudo sed "s/mmsGroupId=/mmsGroupId=588132557f3f5b2190ad6e23/g" /etc/mongodb-mms/automation-agent.config |     sed "s/mmsApiKey=/mmsApiKey=a82c9e18ed53e9846396c16da4fe97e7/g" |     sed "s/mmsBaseUrl=/mmsBaseUrl=http:\/\/ec2-54-202-110-174.us-west-2.compute.amazonaws.com:8080/g" |     tee /tmp/automation-agent.config
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
sudo yum -y erase 
sudo rm -rf /var/log/mongodb
sudo rm -rf /var/lib/mongo

# Connecting to MongoS
mongo ec2-54-202-233-130.us-west-2.compute.amazonaws.com

# Run on Laptop Uploading the jar file
# scp -i ~/.ssh/amazonaws_rsa ~/Code/work/mongodb/git-hub/poc-driver/bin/POCDriver.jar  ec2-user@ec2-54-187-204-32.us-west-2.compute.amazonaws.com:/home/ec2-user

# Download jar file on servers
# scp -i ~/.ssh/amazonaws_rsa ~/Code/work/mongodb/git-hub/poc-driver/bin/POCDriver.jar  ec2-user@ec2-54-187-204-32.us-west-2.compute.amazonaws.com:/home/ec2-user
wget --no-check-certificate 'https://docs.google.com/uc?export=download&id=0B4KRgMp8k0BieHpHQWZkT1g5Y1k' -O POCDriver.jar


ssh -i ~/.ssh/amazonaws_rsa ec2-user@ec2-54-187-28-219.us-west-2.compute.amazonaws.com
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
sudo sed "s/mmsGroupId=/mmsGroupId=588132557f3f5b2190ad6e23/g" /etc/mongodb-mms/backup-agent.config |     sed "s/mmsApiKey=/mmsApiKey=a82c9e18ed53e9846396c16da4fe97e7/g" |     sed "s/mmsBaseUrl=/mmsBaseUrl=http:\/\/ec2-54-202-110-174.us-west-2.compute.amazonaws.com:8080/g" |     tee /tmp/backup-agent.config
sudo cp /tmp/backup-agent.config /etc/mongodb-mms/backup-agent.config
sudo cat /etc/mongodb-mms/backup-agent.config
sudo service mongodb-mms-backup-agent start





# Questions 
# https://mongodb--c.na7.visual.force.com/apex/Console_CaseView?id=500A000000W8ENaIAN&sfdc.override=1
# https://support.mongodb.com/case/00421662

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

