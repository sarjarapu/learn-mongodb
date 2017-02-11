#!/bin/sh


############################################################
# Documentation:
#   https://docs.opsmanager.mongodb.com/v3.4/tutorial/install-basic-deployment/
# Tools:
#   brew install https://raw.githubusercontent.com/djui/i2cssh/master/i2cssh.rb
############################################################

osFlavor='amzl' # amazon rhel
awsSSHUser='ec2-user'
awsRegionName='us-west-2'
awsInstanceTagName='ska-ors-demo'
awsPrivateKeyName='amazonaws_rsa'
awsPrivateKeyPath="~/.ssh/$awsPrivateKeyName"
scriptsFolder='./scripts'
rsAppDBName='rsAppDB'
rsOplogDBName='rsOplogDB'
rsAppDBUser='superuser'
rsAppDBPassword='secret'
rsAppDBRoles="'root'"
rsOplogDBUser='superuser'
rsOplogDBPassword='secret'
rsOplogDBRoles="'root'"
rsAppDBKeyfileSalt='secretSaltAppDB'
rsOplogDBKeyfileSalt='secretSaltOplogDB'
dataFolder='/data'
appDBPort='27000'
oplogDBPort='27001'
rsOplogStoreName='rsOplogStore'


# Thinks I might want to customize in here 
# changes to password keyfiles 
# Script merger for me to do standard deployments real quick 
# abilitiy to scp merged script and run them automatically 
# support username and password, roles  for the default user we create 
# clean up of default installed mongodb or reuse it for the appdb 
# change the path and replicaset names real quick 
# start up scripts is becoming major head ache  for each OS. have them working 

############################################################
# Do not modiy anything below this 
############################################################
rm -rf $scriptsFolder
mkdir $scriptsFolder 

############################################################
# EC2 Instance details  
############################################################
# query aws instances by tag name: ska-ors-demo, Sort the instances by private IP addresses 
# aws ec2 describe-instances --region "us-west-2" --filter "Name=tag:Name,Values=ska-ors-demo" --filter "Name=instance-id,Values=i-005299fa916a10252" --query "Reservations[*].Instances[*].[InstanceId,PublicDnsName,PrivateDnsName]" --output text

result=$(aws --region "$awsRegionName" ec2 describe-instances --filters "Name=tag:Name,Values=$awsInstanceTagName")

# Stash the instances, private dns & public dns names into the array variables 
instanceIds=($(echo "$result" | sed -n  's/"InstanceId": "\([^"]*\)",/\1/p' | sed -n 's/[ ]*//p'))
privateDNSNames=($(echo "$result" | sed -n  's/"PrivateDnsName": "\([^"]*\)",/\1/p' | sed -n 's/[ ]*//p' | uniq))
publicDNSNames=($(echo "$result" | sed -n  's/"PublicDnsName": "\([^"]*\)",/\1/p' | sed -n 's/[ ]*//p' | uniq))

: '
printf '%s\n' "${instanceIds[@]}"
printf '%s\n' "${privateDNSNames[@]}"
printf '%s\n' "${publicDNSNames[@]}"
'

############################################################
# Install a Basic Production Deployment on RHEL or Amazon Linux
# https://docs.opsmanager.mongodb.com/v3.4/tutorial/install-basic-deployment/
############################################################

# Setup: 
# Servers:  server-1    server-2    server-3
#   AppDB:  primary     secondary   secondary
#  OplgDB:  secondary   primary     secondary
#  OpsWeb:  http        http
#  Daemon:              BackupD

############################################################
# Update your i2csshrc with instance public IPs  
############################################################

tee "$scriptsFolder/i2csshrc" <<EOF
version: 2
iterm2: true
clusters:
  aws_ors_omgr:
    login: $awsSSHUser
    hosts:
      - ${publicDNSNames[0]}
      - ${publicDNSNames[1]}
      - ${publicDNSNames[2]}
  aws_ors_mongo:
    login: $awsSSHUser
    hosts:
      - ${publicDNSNames[3]}
      - ${publicDNSNames[4]}
      - ${publicDNSNames[5]}
      - ${publicDNSNames[6]}
      - ${publicDNSNames[7]}
      - ${publicDNSNames[8]}
      - ${publicDNSNames[9]}
      - ${publicDNSNames[10]}
      - ${publicDNSNames[11]}
  aws_ors_pool:
    login: $awsSSHUser
    hosts:
      - ${publicDNSNames[12]}
      - ${publicDNSNames[13]}
      - ${publicDNSNames[14]}
      - ${publicDNSNames[15]}
      - ${publicDNSNames[16]}
      - ${publicDNSNames[17]}
EOF

cp "$scriptsFolder/i2csshrc" ~/.i2csshrc

tee "$scriptsFolder/01.opsmgr.appdb.install.sh" <<INSOPSMGR
############################################################
# Ops Manager DB: Installing the MongoDB
############################################################
i2cssh -Xi=$awsPrivateKeyPath -c aws_ors_omgr

# Double check the 3 server private name with below before you run these commands 
# Server #1: ${privateDNSNames[0]}
# Server #2: ${privateDNSNames[1]}
# Server #3: ${privateDNSNames[2]}

# Cmd + Shift + I
# inject to run it via aws cli 

if [ '$osFlavor' == 'rhel' ]
then
# In CentOS 7 $releasever is not being resolved properly to 7
releasever=7
sudo tee /etc/yum.repos.d/mongodb-enterprise.repo <<EOF
[mongodb-enterprise]
name=MongoDB Enterprise Repository
baseurl=https://repo.mongodb.com/yum/redhat/\$releasever/mongodb-enterprise/3.4/\\\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.4.asc
EOF
else
sudo tee /etc/yum.repos.d/mongodb-enterprise.repo <<EOF
[mongodb-enterprise]
name=MongoDB Enterprise Repository
baseurl=https://repo.mongodb.com/yum/amazon/2013.03/mongodb-enterprise/3.4/\\\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.4.asc
EOF
fi


# Without yum -y upgrade , there is enterprise lib*.so dependency failures I have come across while automating on AMZL 
sudo yum -y upgrade 
sudo yum install -y mongodb-enterprise
sudo mkdir -p $dataFolder/appdb/db
sudo chown -R mongod:mongod $dataFolder

sudo -u mongod tee $dataFolder/appdb/mongod.conf  <<EOF 
systemLog:
   destination: file
   path: $dataFolder/appdb/mongod.log
   logAppend: true
storage:
   dbPath: $dataFolder/appdb/db
processManagement:
   fork: true
   pidFilePath: $dataFolder/appdb/mongod.pid
net:
   port: $appDBPort
replication:
   replSetName: $rsAppDBName
security:
   authorization: enabled
   keyFile: $dataFolder/appdb/keyfile
EOF

sudo -u mongod sh -c "echo $rsAppDBKeyfileSalt | openssl sha1 -sha512  | sed 's/(stdin)= //g' > $dataFolder/appdb/keyfile"
sleep 1
sudo -u mongod sh -c 'chmod 400 $dataFolder/appdb/keyfile'
sudo -u mongod /usr/bin/mongod --config $dataFolder/appdb/mongod.conf 
sleep 2
INSOPSMGR


tee "$scriptsFolder/02.opsmgr.appdb.configrs.sh" <<CONFAPPDB
############################################################
# Ops Manager DB: Configure MongoDB ReplicaSet
# Run only on Server #1: ${privateDNSNames[0]}
############################################################

mongo --port $appDBPort <<EOF
use admin
rs.initiate({_id: '$rsAppDBName', 'members' : [{ '_id' : 0, 'host' : '${privateDNSNames[0]}:$appDBPort', priority: 5 }]})
sleep(10000)
db.createUser({user: '$rsAppDBUser', pwd: '$rsAppDBPassword', roles: [$rsAppDBRoles]})
db.auth('$rsAppDBUser', '$rsAppDBPassword')
rs.add({ host: '${privateDNSNames[1]}:$appDBPort' })
rs.add({ host: '${privateDNSNames[2]}:$appDBPort' })
EOF
CONFAPPDB


tee "$scriptsFolder/03.opsmgr.oplogdb.install.sh" <<INITDAPPDB
############################################################
# Backup DB: Installing the MongoDB
############################################################
sudo mkdir -p $dataFolder/oplogstore/db
sudo chown mongod:mongod -R $dataFolder

sudo -u mongod tee $dataFolder/oplogstore/mongod.conf  <<EOF
systemLog:
   destination: file
   path: $dataFolder/oplogstore/mongod.log
   logAppend: true
storage:
   dbPath: $dataFolder/oplogstore/db
processManagement:
   fork: true
   pidFilePath: $dataFolder/oplogstore/mongod.pid
net:
   port: $oplogDBPort
replication:
   replSetName: $rsOplogStoreName
security:
   authorization: enabled
   keyFile: $dataFolder/oplogstore/keyfile
EOF

sudo -u mongod sh -c "echo $rsOplogDBKeyfileSalt | openssl sha1 -sha512  | sed 's/(stdin)= //g' > $dataFolder/oplogstore/keyfile"
sleep 1
sudo -u mongod sh -c 'chmod 400 $dataFolder/oplogstore/keyfile'
sudo -u mongod /usr/bin/mongod --config $dataFolder/oplogstore/mongod.conf 
sleep 2
INITDAPPDB


tee "$scriptsFolder/04.opsmgr.oplogdb.configrs.sh" <<CONFOPLOGDB
############################################################
# Backup DB: Configure MongoDB ReplicaSet
# Run only on Server #2: ${privateDNSNames[1]}
############################################################

mongo --port $oplogDBPort <<EOF
use admin
rs.initiate({_id: '$rsOplogStoreName', 'members' : [{ '_id' : 0, 'host' : '${privateDNSNames[0]}:$oplogDBPort'}]})
sleep(10000)
db.createUser({user: '$rsOplogDBUser', pwd: '$rsOplogDBPassword', roles: [$rsOplogDBRoles]})
db.auth('$rsOplogDBUser', '$rsOplogDBPassword')

rs.add({ host: '${privateDNSNames[1]}:$oplogDBPort', priority: 5 })
rs.add({ host: '${privateDNSNames[2]}:$oplogDBPort' })
sleep(3000)
EOF
CONFOPLOGDB


tee "$scriptsFolder/05.opsmgr.appdb.initd.sh" <<INITDAPPDB
############################################################
# Ops Manager DB: Create the init.d startup scripts 
############################################################

sudo chown -R mongod:mongod $dataFolder

if [ '$osFlavor' == 'rhel' ]
then
sudo curl https://raw.githubusercontent.com/mongodb/mongo/master/rpm/mongod.service --output /tmp/mongod.service

cat /tmp/mongod.service | \
    sed 's#/etc/mongod.conf#$dataFolder/appdb/mongod.conf#g' | \
    sed 's#/var/run/mongodb#$dataFolder/appdb#g' | \
    sed 's# -p $dataFolder/appdb# -p $dataFolder/appdb/db#g' | \
    sed 's/mongod.pid/mongod-appdb.pid/g' | \
    sed 's#Description=.*#Description=Ops Manager MongoDB instance for AppDB#g' | \
    sudo tee /lib/systemd/system/mongod-appdb.service

sudo chcon -vR --user=system_u --type=mongod_var_lib_t $dataFolder/appdb
sudo chcon -v --user=system_u --type=mongod_unit_file_t /lib/systemd/system/mongod-appdb.service

sudo systemctl enable mongod-appdb.service 
sudo systemctl start mongod-appdb.service 

else
sed 's#/etc/mongod.conf#$dataFolder/appdb/mongod.conf#g' /etc/init.d/mongod | sudo tee /etc/init.d/mongod-appdb
sudo chown mongod:mongod /etc/init.d/mongod-appdb
sudo chmod +x /etc/init.d/mongod-appdb
sudo chkconfig --add mongod-appdb
sudo chkconfig mongod-appdb on
sudo service mongod-appdb restart
fi

INITDAPPDB


tee "$scriptsFolder/06.opsmgr.oplogdb.initd.sh" <<INITDOPLOGDB
############################################################
# Backup DB: Create the init.d startup scripts 
############################################################
if [ '$osFlavor' == 'rhel' ]
then
sudo curl https://raw.githubusercontent.com/mongodb/mongo/master/rpm/mongod.service --output /tmp/mongod.service

cat /tmp/mongod.service | \
    sed 's#/etc/mongod.conf#$dataFolder/oplogstore/mongod.conf#g' | \
    sed 's#/var/run/mongodb#$dataFolder/oplogstore#g' | \
    sed 's# -p $dataFolder/oplogstore# -p $dataFolder/oplogstore/db#g' | \
    sed 's#Description=.*#Description=Ops Manager MongoDB instance for OplogStore#g' | \
    sudo tee /lib/systemd/system/mongod-oplogstore.service

sudo chcon -vR --user=system_u --type=mongod_var_lib_t $dataFolder/oplogstore
sudo chcon -v --user=system_u --type=mongod_unit_file_t /lib/systemd/system/mongod-oplogstore.service

sudo systemctl enable mongod-oplogstore.service 
sudo systemctl start mongod-oplogstore.service 

else
sed 's#/etc/mongod.conf#$dataFolder/oplogstore/mongod.conf#g' /etc/init.d/mongod | sudo tee /etc/init.d/mongod-oplogstore
sudo chown mongod:mongod /etc/init.d/mongod-oplogstore
sudo chmod +x /etc/init.d/mongod-oplogstore
sudo chkconfig --add mongod-oplogstore
sudo chkconfig mongod-oplogstore on
sudo service mongod-appdb restart
fi

INITDOPLOGDB


tee "$scriptsFolder/07.opsmgr.install.http.sh" <<INSHTTP
############################################################
# Ops Manager: Install HTTP Service
# Server #1: ${privateDNSNames[0]}
# Server #3: ${privateDNSNames[2]}
# https://docs.opsmanager.mongodb.com/current/tutorial/install-on-prem-with-rpm-packages/
############################################################
if [ '$osFlavor' == 'rhel' ]
then
sudo yum install -y wget
fi

wget https://downloads.mongodb.com/on-prem-mms/rpm/mongodb-mms-3.4.1.385-1.x86_64.rpm
sudo rpm -ivh mongodb-mms-3.4.1.385-1.x86_64.rpm
# sudo vi /opt/mongodb/mms/conf/conf-mms.properties

# Goto this line and replace connection string 
# mongo.mongoUri=mongodb://127.0.0.1:27017/?maxPoolSize=150

cat /opt/mongodb/mms/conf/conf-mms.properties | sed 's#mongoUri=.*\$#mongoUri=mongodb://$rsAppDBUser:$rsAppDBPassword@${privateDNSNames[0]}:$appDBPort,${privateDNSNames[1]}:$appDBPort,${privateDNSNames[2]}:$appDBPort/?authSource=admin\&replicaSet=$rsAppDBName\&maxPoolSize=150#g' | sudo tee /opt/mongodb/mms/conf/conf-mms.properties

INSHTTP


tee "$scriptsFolder/08.opsmgr.start.http.sh" <<STARTHTTP
############################################################
# Ops Manager: Start only one of the Server #1
# Server #1: ${publicDNSNames[0]} / ${privateDNSNames[0]}
# Notes: Will take 5 mins. 
############################################################
sudo service mongodb-mms start
STARTHTTP

tee "$scriptsFolder/09.opsmgr.config.http.sh" <<CONFIGHTTP
############################################################
# Ops Manager: Conigure the Ops Manager via UI
############################################################
# http://${publicDNSNames[0]}:8080
# http://${privateDNSNames[0]}:8080
# shyam.arjarapu@10gen.com ORS smtp.gmail.com

############################################################
# Ops Manager: Copy /etc/mongodb-mms/gen.key from Server #1 to #3
# Copy gen.key, start mms, create backup deamon folder
############################################################
scp -i $awsPrivateKeyPath $awsPrivateKeyPath  $awsSSHUser@${publicDNSNames[0]}:/home/$awsSSHUser
sudo scp -i $awsPrivateKeyName /etc/mongodb-mms/gen.key  $awsSSHUser@${privateDNSNames[2]}:/home/$awsSSHUser
sudo scp -i $awsPrivateKeyName /etc/mongodb-mms/gen.key  $awsSSHUser@${privateDNSNames[1]}:/home/$awsSSHUser

sudo mv gen.key /etc/mongodb-mms/gen.key
sudo chown mongodb-mms:mongodb-mms /etc/mongodb-mms/gen.key
sudo service mongodb-mms start

############################################################
# Filesystem Store: On Ops Manager HTTP Server # 1 & #3
############################################################
sudo mkdir -p /backup/fileSystemStore
sudo chown mongodb-mms:mongodb-mms /backup /backup/fileSystemStore
CONFIGHTTP


tee "$scriptsFolder/10.opsmgr.config.backup.sh" <<CONFIGBACKUP
############################################################
# Backup Daemon: On Server #3 create headdb folder
# Server #3: ${privateDNSNames[2]}
# Double check from UI
############################################################
sudo mkdir -p /backup/headdb
sudo chown mongodb-mms:mongodb-mms /backup /backup/headdb

# Ops Manager UI: Backup > configure the backup module
# /backup/headdb
# enable daemon
# /backup/fileSystemStore

# user: $rsOplogDBUser
# password: $rsOplogDBPassword
# servers: ${privateDNSNames[0]}:$oplogDBPort,${privateDNSNames[1]}:$oplogDBPort,${privateDNSNames[2]}:$oplogDBPort
# options: authSource=admin&replicaSet=$rsOplogStoreName&maxPoolSize=150
CONFIGBACKUP


tee "$scriptsFolder/11.opsmgr.install.agents.sh" <<INSAGENTS
###############################################################
# Install Automation Agents
###############################################################
i2cssh -Xi=~/.ssh/amazonaws_rsa -c aws_ors_mongo
sudo yum -y upgrade 

opsmgrUri=${publicDNSNames[0]}
rpmVersion=3.2.8.1942-1.x86_64
mmsGroupId=589cfc39dd9b172290a751c2
mmsApiKey=56d23d836b0ba6c55e368a853e86de63


curl -OL http://\$opsmgrUri:8080/download/agent/automation/mongodb-mms-automation-agent-manager-\$rpmVersion.rpm
sudo rpm -U mongodb-mms-automation-agent-manager-\$rpmVersion.rpm

sudo cp /etc/mongodb-mms/automation-agent.config /tmp/automation-agent.orig.config
sudo sed 's/mmsGroupId=.*\$/mmsGroupId=\$mmsGroupId/g' /etc/mongodb-mms/automation-agent.config | \
    sed 's/mmsApiKey=.*\$/mmsApiKey=\$mmsApiKey/g' | \
    sed 's/mmsBaseUrl=.*\$/mmsBaseUrl=http:\/\/\$opsmgrUri:8080/g' | \
    tee /tmp/automation-agent.config
sudo -u mongod cp /tmp/automation-agent.config /etc/mongodb-mms/automation-agent.config
sudo cat /etc/mongodb-mms/automation-agent.config

sudo mkdir -p $dataFolder
sudo chown mongod:mongod $dataFolder
sudo service mongodb-mms-automation-agent start
INSAGENTS


tee "$scriptsFolder/12.opsmgr.install.pool.sh" <<INSPOOL
###############################################################
# Pool: Install Automation Agents
###############################################################

opsmgrUri=${publicDNSNames[0]}
rpmVersion=3.2.8.1942-1.x86_64
serverPoolKey=4e324700df392529b115cb2b992efb14
mmsApiKey=3136703d14c1919ee176180c2b5d7157

i2cssh -Xi=~/.ssh/amazonaws_rsa -c aws_ors_pool
sudo yum -y upgrade 

curl -OL http://$opsmgrUri:8080/download/agent/automation/mongodb-mms-automation-agent-manager-3.2.8.1942-1.x86_64.rpm
sudo rpm -U mongodb-mms-automation-agent-manager-$rpmVersion.rpm

sudo cp /etc/mongodb-mms/automation-agent.config /tmp/automation-agent.orig.config
sudo sed 's/serverPoolKey=/serverPoolKey=$serverPoolKey/g' /etc/mongodb-mms/automation-agent.config | \
    sed 's/mmsBaseUrl=/mmsBaseUrl=http:\/\/$opsmgrUri:8080/g' | \
    tee /tmp/automation-agent.config
sudo -u mongod cp /tmp/automation-agent.config /etc/mongodb-mms/automation-agent.config
sudo cat /etc/mongodb-mms/automation-agent.config


# 1 MEDIUM across US-EAST, US-CENTRAL, US-WEST
# 3 LARGE across US-EAST
# Stopped: 1 Large instance
sudo -u mongod tee /etc/mongodb-mms/server-pool.properties <<EOF 
Datacenter=US-EAST
Size=MEDIUM
EOF

sudo -u mongod tee /etc/mongodb-mms/server-pool.properties <<EOF 
Datacenter=US-EAST
Size=LARGE
EOF

sudo -u mongod vi /etc/mongodb-mms/server-pool.properties 

sudo mkdir -p $dataFolder
sudo chown mongod:mongod $dataFolder
sudo service mongodb-mms-automation-agent start

# regex  ip-172-31-13-163|ip-172-31-6-73|ip-172-31-8-94
INSPOOL


cat "$scriptsFolder/01.opsmgr.appdb.install.sh" "$scriptsFolder/03.opsmgr.oplogdb.install.sh" > "$scriptsFolder/99.01.opsmgr.appdb.oplogdb.install.sh" 
cat "$scriptsFolder/02.opsmgr.appdb.configrs.sh" "$scriptsFolder/04.opsmgr.oplogdb.configrs.sh" > "$scriptsFolder/99.02.opsmgr.appdb.oplogdb.configrs.sh" 


tee "$scriptsFolder/90.opsmgr.do.other.sh" <<OTHER
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


sudo mkdir -p $dataFolder/db
sudo chown mongod:mongod $dataFolder $dataFolder/db

sudo tee /etc/mongod.conf  <<EOF 
logpath=$dataFolder/mongod.log
logappend=true
fork=true
dbpath=$dataFolder/db
pidfilepath=$dataFolder/mongod.pid
#auth=true
replSet=progresoReplSet
keyFile=$dataFolder/keyfile
EOF
sudo chown mongod:mongod /etc/mongod.conf

sudo -u mongod sh -c 'echo $rsAppDBPasswordsaltprogresoReplSet | openssl sha1 -sha512  | sed 's/(stdin)= //g' > $dataFolder/keyfile'
sudo -u mongod sh -c 'chmod 400 $dataFolder/keyfile'
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
db.createUser({user: 'mms-automation', pwd: '$mmsAutomationPassword', roles: ['clusterAdmin', 'dbAdminAnyDatabase', 'readWriteAnyDatabase', 'restore', 'userAdminAnyDatabase']})

# Gotcha: 
# use $dataFolder/db for database never do $dataFolder 
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
scp -i ~/.ssh/amazonaws_rsa /Users/shyamarjarapu/Code/work/mongodb/git-hub/poc-driver/bin/POCDriver.jar  $awsSSHUser@ec2-54-244-159-69.us-west-2.compute.amazonaws.com:/home/$awsSSHUser
scp -i ~/.ssh/amazonaws_rsa /Users/shyamarjarapu/Code/work/mongodb/git-hub/poc-driver/bin/POCDriver.jar  $awsSSHUser@ec2-54-244-161-108.us-west-2.compute.amazonaws.com:/home/$awsSSHUser
scp -i ~/.ssh/amazonaws_rsa /Users/shyamarjarapu/Code/work/mongodb/git-hub/poc-driver/bin/POCDriver.jar  $awsSSHUser@ec2-54-244-161-117.us-west-2.compute.amazonaws.com:/home/$awsSSHUser
java -jar POCDriver.jar -i 20 -k 20 -b 10 -u 20 -c 'mongodb://root:$rsAppDBPassword@ec2-54-244-159-69.us-west-2.compute.amazonaws.com:$appDBPort/?authSource=admin&replicaSet=rsProd-AppDB'
java -jar POCDriver.jar -i 60 -k 30 -b 10 -c 'mongodb://root:$rsAppDBPassword@ec2-54-244-159-69.us-west-2.compute.amazonaws.com:$appDBPort/?authSource=admin&replicaSet=rsProd-AppDB'





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
sudo sed 's/mmsGroupId=/mmsGroupId=588132557f3f5b2190ad6e23/g' /etc/mongodb-mms/automation-agent.config | \
    sed 's/mmsApiKey=/mmsApiKey=a82c9e18ed53e9846396c16da4fe97e7/g' | \
    sed 's/mmsBaseUrl=/mmsBaseUrl=http:\/\/ec2-54-202-110-174.us-west-2.compute.amazonaws.com:8080/g' | \
    tee /tmp/automation-agent.config
sudo cp /tmp/automation-agent.config /etc/mongodb-mms/automation-agent.config
sudo cat /etc/mongodb-mms/automation-agent.config

sudo mkdir -p $dataFolder
sudo chown mongod:mongod $dataFolder
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
java -jar POCDriver.jar -i 20 -k 20 -b 10 -u 20 -c 'mongodb://ip-172-31-33-163.us-west-2.compute.internal:27017/'

java -jar POCDriver.jar -i 20 -k 20 -b 10 -u 20 -c 'mongodb://ip-172-31-33-164.us-west-2.compute.internal:27017/'


# java -jar POCDriver.jar -i 20 -k 20 -b 10 -u 20 -c 'mongodb://ip-172-31-9-250.us-west-2.compute.internal:27017/'
# java -jar POCDriver.jar -i 20 -k 20 -b 10 -u 20 -c 'mongodb://ip-172-31-9-251.us-west-2.compute.internal:27017/'
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
sudo sed 's/mmsGroupId=/mmsGroupId=588132557f3f5b2190ad6e23/g' /etc/mongodb-mms/backup-agent.config | \
    sed 's/mmsApiKey=/mmsApiKey=a82c9e18ed53e9846396c16da4fe97e7/g' | \
    sed 's/mmsBaseUrl=/mmsBaseUrl=http:\/\/ec2-54-202-110-174.us-west-2.compute.amazonaws.com:8080/g' | \
    tee /tmp/backup-agent.config
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
mongo --port 27017 --eval 'db.getSiblingDB('BirstDB').stats()'
mongo --port 27017 --eval 'db.serverStatus()'
sudo -u mongod sh -c 'ulimit -a'
numactl --hardware
sysctl net.ipv4.tcp_keepalive_time
sudo sysctl vm.zone_reclaim_mode

# can you run it on the device where your mongod is installing 
# sudo blockdev --getra /dev/xvda



sudo mv /etc/rc.d/init.d/mongod /etc/rc.d/init.d/mongod-appdb
sudo cp /etc/rc.d/init.d/mongod-appdb /etc/rc.d/init.d/mongod-oplogstore


sudo -u mongod sh -c 'sed -i  's#/etc/mongod.conf#$dataFolder/appdb/mongod.conf#g' /etc/rc.d/init.d/mongod-appdb'
sudo -u mongod sed -i  's#/etc/mongod.conf#$dataFolder/oplogstore/mongod.conf#g' /etc/rc.d/init.d/mongod-oplogstore

sudo chown mongod -R $dataFolder
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

OTHER