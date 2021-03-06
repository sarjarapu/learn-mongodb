#!/bin/sh



############################################################
# Documentation:
#   https://docs.opsmanager.mongodb.com/v3.4/tutorial/install-basic-deployment/
# Tools:
#   brew install https://raw.githubusercontent.com/djui/i2cssh/master/i2cssh.rb
# Notes: 
#   Amazon: m4.2xlarge, 60 GB disk, 15 instances, Oregon, vpc-0cdb1d68, us-west-2c
#   Total WTC: 5% = 3 GB. (Backups require oplog window > 24 hrs) 
#     or Replication  Window < 0.128 GB / hour
#   If init.d scripts aren't starting the process delete /data/appdb/mongod.pid 
#   init.d script needs some fix in deleting the pid 
#   http://ska-clb-01-2076939081.us-west-2.elb.amazonaws.com:8080/user/login
# 
#   Issues: How to manually restore .tar > .cpgz file ?
# sudo yum install -y xfsprogs xfsdump
# lsblk
# sudo mkfs.xfs /dev/xvdf
# sudo mkdir /backup
# ??? user auth multiple deployments same db credentials ???
############################################################

############################################################
# Install a Basic Production Deployment on RHEL or Amazon Linux
# https://docs.opsmanager.mongodb.com/v3.4/tutorial/install-basic-deployment/
############################################################

# Setup: 
# Servers:  server-1      server-2       server-3
#   AppDB:  primary       secondary      sec / arb
#  OplgDB:  sec / arb     secondary      primary
#  OpsWeb:  http        
#  Daemon:                BackupD
# File SS:  mount 

awsInstanceTagName='ska-ors'
# expects to have images ska-ors-omgr, ska-ors-mongo and ska-ors-pool
osFlavor='amazon' # amazon rhel ubuntu
awsSSHUser='ec2-user'
useArbiter='true'

awsRegionName='us-west-2'
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
mongoUser='mongod'
isForkable='true' #fork: true in config setting. Not applicable in Windows. 

addOther='add'
if [ "$useArbiter" == "true" ]; then
	addOther='addArb'
fi

if [ "$osFlavor" == "ubuntu" ]; then
	mongoUser='mongodb'
    awsSSHUser='ubuntu'
    isForkable='false'
fi


# Thinks I might want to customize in here 
# changes to password keyfiles 
# Script merger for me to do standard deployments real quick 
# abilitiy to scp merged script and run them automatically 
# support username and password, roles  for the default user we create 
# clean up of default installed mongodb or reuse it for the appdb 
# change the path and replicaset names real quick 
# start up scripts is becoming major head ache  for each OS. have them working 
# Tags: ska-ors-omgr ska-ors-demo ska-ors-import ska-ors-pool 
# Change app/data/ to default mongod.conf
# may be leave the log pid files in the default place but with soft linkes ?


############################################################
# Gotcha's
############################################################
# After reboot /var/run/mongod.pid file got deleted, try to plug it into the .service file 
# After reboot /mount points for the /data is missing 


############################################################
# Do not modiy anything below this 
############################################################
rm -rf $scriptsFolder
mkdir $scriptsFolder $scriptsFolder/certs

# rm ~/.ssh/known_hosts
# touch ~/.ssh/known_hosts

############################################################
# EC2 Instance details  
############################################################
# query aws instances by tag name: ska-ors-demo, Sort the instances by private IP addresses 
# aws ec2 describe-instances --region "us-west-2" --filter "Name=tag:Name,Values=ska-ors-demo*" --query "Reservations[*].Instances[*].[PublicDnsName,PrivateDnsName,omgrInstanceIds]" --output text | sort | tr "\t" "," | cut -d',' -f1
omgrResult=($(aws ec2 describe-instances --region "$awsRegionName" --filter "Name=tag:Name,Values=$awsInstanceTagName-omgr" --query "Reservations[*].Instances[*].[PublicDnsName,PrivateDnsName,InstanceId,Tags[?Key=='Name'].Value[] | [0]]" --output text | sort | tr "\t" "," ))
omgrPublicDNS=($(printf '%s\n' "${omgrResult[@]}" | cut -d',' -f1))
omgrPrivateDNS=($(printf '%s\n' "${omgrResult[@]}" | cut -d',' -f2))
omgrInstanceIds=($(printf '%s\n' "${omgrResult[@]}" | cut -d',' -f3))

mongoResult=($(aws ec2 describe-instances --region "$awsRegionName" --filter "Name=tag:Name,Values=$awsInstanceTagName-mongo" --query "Reservations[*].Instances[*].[PublicDnsName,PrivateDnsName,InstanceId,Tags[?Key=='Name'].Value[] | [0]]" --output text | sort | tr "\t" "," ))
mongoPublicDNS=($(printf '%s\n' "${mongoResult[@]}" | cut -d',' -f1))
mongoPrivateDNS=($(printf '%s\n' "${mongoResult[@]}" | cut -d',' -f2))
mongoInstanceIds=($(printf '%s\n' "${mongoResult[@]}" | cut -d',' -f3))




############################################################
# Create machine.info lookup file 
############################################################
echo "
# Ops Manager 
`printf '%s\n' "${omgrResult[@]}"`

# Mongo
`printf '%s\n' "${mongoResult[@]}"`

# Load Balancer configuration
# 172.31.1.88            ska-certauthority.us-west-2.compute.internal
http://ska-clb-01-2076939081.us-west-2.elb.amazonaws.com
:8080
/user/login
${omgrInstanceIds[0]}
${omgrInstanceIds[1]}
${omgrInstanceIds[2]}

# TODO: Fix the \n escape 
: '
printf '%s\\n' "\${omgrPrivateDNS[@]}"
printf '%s\\n' "\${omgrPublicDNS[@]}"
printf '%s\\n' "\${omgrInstanceIds[@]}"

printf '%s\\n' "\${mongoPrivateDNS[@]}"
printf '%s\\n' "\${mongoPublicDNS[@]}"
printf '%s\\n' "\${mongoInstanceIds[@]}"

'

" > "$scriptsFolder/machines.info.txt"


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
      - ${omgrPublicDNS[0]}
      - ${omgrPublicDNS[1]}
      - ${omgrPublicDNS[2]}
  aws_ors_mongo:
    login: $awsSSHUser
    hosts:
      - ${mongoPublicDNS[0]}
      - ${mongoPublicDNS[1]}
      - ${mongoPublicDNS[2]}
      - ${mongoPublicDNS[3]}
      - ${mongoPublicDNS[4]}
      - ${mongoPublicDNS[5]}
      - ${mongoPublicDNS[6]}
      - ${mongoPublicDNS[7]}
      - ${mongoPublicDNS[8]}
  aws_ors_pool:
    login: $awsSSHUser
    hosts:
      - ${poolPublicDNS[0]}
      - ${poolPublicDNS[1]}
      - ${poolPublicDNS[2]}
      - ${poolPublicDNS[3]}
      - ${poolPublicDNS[4]}
      - ${poolPublicDNS[5]}
      - ${poolPublicDNS[6]}
      - ${poolPublicDNS[7]}
EOF

cp "$scriptsFolder/i2csshrc" ~/.i2csshrc

tee "$scriptsFolder/00.drive.creation.sh" <<DRIVEC
############################################################
# Optional: Create drive mapping for /data 
############################################################
sudo apt-get install xfsprogs
lsblk
# sudo umount /dev/xvdb1
# sudo fdisk /dev/xvdb
# n - new partition
# p - primary 
# pn - 1
#
#
# w
sudo mkfs.xfs -f /dev/xvdb1
sudo mkdir -p /data
sudo mount /dev/xvdb1 /data

# mongodb user not available until mongodb is installed 
# sudo chown -R $mongoUser:$mongoUser /data

# Use 'blkid' to print the universally unique identifier for a
# <file system> <mount point> <type> <options> <dump> <pass>
echo '/dev/xvdb1		/data	 xfs	defaults,noatime		0 0' >> /etc/fstab

DRIVEC


tee "$scriptsFolder/01.opsmgr.appdb.install.sh" <<INSOPSMGR
############################################################
# Ops Manager DB: Installing the MongoDB
############################################################
# Run this command on your local box
# i2cssh -Xi=$awsPrivateKeyPath -c aws_ors_omgr

# Double check the 3 server private name with below before you run these commands 
# Server #1: ${omgrPrivateDNS[0]}
# Server #2: ${omgrPrivateDNS[1]}
# Server #3: ${omgrPrivateDNS[2]}

# Cmd + Shift + I
# inject to run it via aws cli 

if [ '$osFlavor' == 'rhel' ]
then
# In CentOS 7 $releasever is not being resolved properly to 7
# releasever=7
sudo tee /etc/yum.repos.d/mongodb-enterprise.repo <<EOF
[mongodb-enterprise]
name=MongoDB Enterprise Repository
baseurl=https://repo.mongodb.com/yum/redhat/\\\$releasever/mongodb-enterprise/3.4/\\\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.4.asc
EOF
sudo yum -y upgrade 
sudo yum install -y mongodb-enterprise

elif [ '$osFlavor' == 'amazon' ]
then
sudo tee /etc/yum.repos.d/mongodb-enterprise.repo <<EOF
[mongodb-enterprise]
name=MongoDB Enterprise Repository
baseurl=https://repo.mongodb.com/yum/amazon/2013.03/mongodb-enterprise/3.4/\\\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.4.asc
EOF
sudo yum -y upgrade 
sudo yum install -y mongodb-enterprise

else
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6
echo "deb [ arch=amd64,arm64,ppc64el,s390x ] http://repo.mongodb.com/apt/ubuntu xenial/mongodb-enterprise/3.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-enterprise.list
sudo apt-get update
sudo apt-get install -y mongodb-enterprise
fi

# Without yum -y upgrade , there is enterprise lib*.so dependency failures I have come across while automating on amazon_linux 


sudo mkdir -p /data/db /var/run/mongodb /var/lib/mongodb /var/log/mongodb/
sudo rm -rf /var/lib/mongodb
sudo ln -s /data/db /var/lib/mongodb
sudo chown -R mongodb:mongodb /data /var/run/mongodb /var/lib/mongodb /var/log/mongodb/

# Ubuntu didn't work 
#     with -u ; just run without  -u $mongoUser
#     initially disabling security before we add user, then later enable it 
# sudo -u $mongoUser tee /etc/mongod.conf  <<EOF 
# sudo tee /etc/mongod.conf  <<EOF 

sudo tee /etc/mongod.conf  <<EOF 
systemLog:
   destination: file
   path: /var/log/mongodb/mongod.log
   logAppend: true
   logRotate: reopen
storage:
   dbPath: $dataFolder/db
   engine: "wiredTiger"
   wiredTiger:
      engineConfig:
         cacheSizeGB: 8
processManagement:
   pidFilePath: /var/run/mongodb/mongod.pid
   fork: $isForkable
net:
   port: $appDBPort
replication:
   replSetName: $rsAppDBName
#security:
#   authorization: enabled
#   keyFile: $dataFolder/keyfile
EOF

sudo -u $mongoUser sh -c "echo $rsAppDBKeyfileSalt | openssl sha1 -sha512  | sed 's/(stdin)= //g' > $dataFolder/keyfile"
sleep 1
sudo -u $mongoUser sh -c 'chmod 400 $dataFolder/keyfile'


if [ '$osFlavor' == 'ubuntu' ]
then
# Add the missing startpre scripts 
execStartPre='ExecStartPre=/bin/mkdir -p /var/run/mongodb
ExecStartPre=/bin/chown mongodb:mongodb /var/run/mongodb
ExecStartPre=/bin/chmod 0755 /var/run/mongodb
PIDFile=/var/run/mongodb/mongod.pid
PermissionsStartOnly=true'

echo "\`head -8 /lib/systemd/system/mongod.service\`
\$execStartPre
\`tail -n +9 /lib/systemd/system/mongod.service\`" | sudo tee  /lib/systemd/system/mongod.service

# confirm the injection 
cat /lib/systemd/system/mongod.service

# Start the new service and enable it on boot
sudo systemctl --system daemon-reload
sudo systemctl enable mongod.service
sudo systemctl start mongod.service
# sudo systemctl status mongod.service
fi 

# sudo -u $mongoUser /usr/bin/mongod --config /etc/mongod.conf 
sleep 2
INSOPSMGR



tee "$scriptsFolder/02.opsmgr.appdb.configrs.sh" <<CONFAPPDB
############################################################
# Ops Manager DB: Configure MongoDB ReplicaSet
# Run only on Server #1: ${omgrPrivateDNS[0]}
############################################################

mongo --port $appDBPort <<EOF
use admin
rs.initiate({_id: '$rsAppDBName', 'members' : [{ '_id' : 0, 'host' : '${omgrPrivateDNS[0]}:$appDBPort', priority: 5 }]})
sleep(10000)
db.createUser({user: '$rsAppDBUser', pwd: '$rsAppDBPassword', roles: [$rsAppDBRoles]})
db.auth('$rsAppDBUser', '$rsAppDBPassword')
rs.add({ host: '${omgrPrivateDNS[1]}:$appDBPort' })
//rs.add({ host: '${omgrPrivateDNS[2]}:$appDBPort' })
rs.$addOther('${omgrPrivateDNS[2]}:$appDBPort')
EOF
CONFAPPDB

tee "$scriptsFolder/03.opsmgr.oplogdb.install.sh" <<INITDAPPDB
############################################################
# Backup DB: Installing the MongoDB
############################################################
sudo mkdir -p $dataFolder/oplogstore
sudo chown $mongoUser:$mongoUser -R $dataFolder

# TODO: amazon -- etc/mongod-oplogstore.conf path fix in sed regex
# Ubuntu didn't work 
#     with -u ; just run without  -u $mongoUser
#     initially disabling security before we add user, then later enable it 
# sudo -u $mongoUser tee /etc/mongod.conf  <<EOF 
# sudo tee /etc/mongod.conf  <<EOF 

sudo tee /etc/mongod-oplogstore.conf  <<EOF
systemLog:
   destination: file
   path: /var/log/mongodb/mongod-oplogstore.log
   logAppend: true
   logRotate: reopen
storage:
   dbPath: $dataFolder/oplogstore
   engine: "wiredTiger"
   wiredTiger:
      engineConfig:
         cacheSizeGB: 8
processManagement:
   pidFilePath: /var/run/mongodb/mongod-oplogstore.pid
   fork: $isForkable
net:
   port: $oplogDBPort
replication:
   replSetName: $rsOplogStoreName
#security:
#   authorization: enabled
#   keyFile: $dataFolder/oplogstore/keyfile
EOF

sudo -u $mongoUser sh -c "echo $rsOplogDBKeyfileSalt | openssl sha1 -sha512  | sed 's/(stdin)= //g' > $dataFolder/oplogstore/keyfile"
sleep 1
sudo -u $mongoUser sh -c 'chmod 400 $dataFolder/oplogstore/keyfile'
# sudo -u $mongoUser /usr/bin/mongod --config /etc/mongod-oplogstore.conf
# TODO: Ideally I want the start service right here  




# sudo service mongod-oplogstore start
sleep 2
INITDAPPDB


tee "$scriptsFolder/04.opsmgr.oplogdb.configrs.sh" <<CONFOPLOGDB
############################################################
# Backup DB: Configure MongoDB ReplicaSet
# Run only on Server #3: ${omgrPrivateDNS[2]}
############################################################

mongo --port $oplogDBPort <<EOF
use admin
rs.initiate({_id: '$rsOplogStoreName', 'members' : [{ '_id' : 0, 'host' : '${omgrPrivateDNS[2]}:$oplogDBPort', priority: 5 }]})
sleep(10000)
db.createUser({user: '$rsOplogDBUser', pwd: '$rsOplogDBPassword', roles: [$rsOplogDBRoles]})
db.auth('$rsOplogDBUser', '$rsOplogDBPassword')

rs.add({ host: '${omgrPrivateDNS[1]}:$oplogDBPort'})
//rs.add({ host: '${omgrPrivateDNS[0]}:$oplogDBPort' })
rs.$addOther('${omgrPrivateDNS[0]}:$oplogDBPort')
sleep(3000)
EOF
CONFOPLOGDB





tee "$scriptsFolder/05.opsmgr.appdb.initd.sh" <<INITDAPPDB
############################################################
# Ops Manager DB: Create the init.d startup scripts 
# TODO: You might not need this anymore except for the suselinux stuff
############################################################

sudo chown -R $mongoUser:$mongoUser $dataFolder

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

elif [ '$osFlavor' == 'amazon' ]
then
# Amazon Linux init.d scripts works. Delete /data/appdata/mongod.pid file if it doesnt 
sed 's#/etc/mongod.conf#$dataFolder/appdb/mongod.conf#g' /etc/init.d/mongod | sudo tee /etc/init.d/mongod-appdb
sudo chmod +x /etc/init.d/mongod-appdb
sudo chkconfig --add mongod-appdb
sudo chkconfig mongod-appdb on
sudo service mongod-appdb restart

else 

# TODO: Figure out a way to inject it but for now move on with manual injection
# Edit sudo vi /lib/systemd/system/mongod.service
ExecStartPre=/usr/bin/mkdir -p /var/run/mongodb
ExecStartPre=/usr/bin/touch /var/run/mongodb/mongod.pid
ExecStartPre=/usr/bin/chown -R mongod:mongod /var/run/mongodb
ExecStartPre=/usr/bin/chmod 0755 /var/run/mongodb
PermissionsStartOnly=true
PIDFile=/var/run/mongodb/mongod.pid

sudo curl https://raw.githubusercontent.com/mongodb/mongo/master/debian/init.d --output /etc/init.d/mongod
sudo chmod +x /etc/init.d/mongod

cat /lib/systemd/system/mongod.service | \
    sed 's/# file size/$execPreStart# file size/g' | \
    sudo tee /lib/systemd/system/mongod-oplogstore.service

sudo systemctl enable mongod.service 
sudo service mongod start 
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

elif [ '$osFlavor' == 'amazon' ]
then
# Amazon Linux init.d scripts works. Delete /data/oplogstore/mongod.pid file if it doesnt 
sed 's#/etc/mongod.conf#$dataFolder/oplogstore/mongod.conf#g' /etc/init.d/mongod | sudo tee /etc/init.d/mongod-oplogstore
sudo chmod +x /etc/init.d/mongod-oplogstore
sudo chkconfig --add mongod-oplogstore
sudo chkconfig mongod-oplogstore on
sudo service mongod-oplogstore restart

else 

cat /lib/systemd/system/mongod.service | \
    sed 's#mongod\.#mongod-oplogstore.#g' | \
    sudo tee /lib/systemd/system/mongod-oplogstore.service

sudo systemctl --system daemon-reload
sudo systemctl enable mongod-oplogstore.service
sudo systemctl start mongod-oplogstore.service
# sudo systemctl status mongod-oplogstore.service

fi

INITDOPLOGDB

# TODO: Have clean up scripts in here 

tee "$scriptsFolder/07.opsmgr.oplogdb.initd.cleanup.sh" <<INITDCLEANUP
############################################################
# Backup DB: Create the init.d startup scripts 
############################################################
if [ '$osFlavor' == 'rhel' ]
then
sudo systemctl stop mongod.service 
sudo systemctl disable mongod.service 
sudo rm -f /lib/systemd/system/mongod.service
else
# Amazon Linux init.d scripts works. Delete /data/oplogstore/mongod.pid file if it doesnt 
sudo service mongod stop
sudo chkconfig mongod off
sudo chkconfig --del mongod
sudo rm -f /etc/init.d/mongod
fi
INITDCLEANUP

tee "$scriptsFolder/07.opsmgr.install.http.sh" <<INSHTTP
############################################################
# Ops Manager: Install HTTP Service
# Server #1: ${omgrPrivateDNS[0]}
# Server #3: ${omgrPrivateDNS[2]}
# https://docs.opsmanager.mongodb.com/current/tutorial/install-on-prem-with-rpm-packages/
# Get the version links from here https://www.mongodb.com/subscription/downloads/ops-manager
############################################################
if [ '$osFlavor' == 'rhel' ]
then
sudo yum install -y wget
wget https://downloads.mongodb.com/on-prem-mms/rpm/mongodb-mms-3.4.3.402-1.x86_64.rpm
sudo rpm -ivh mongodb-mms-3.4.3.402-1.x86_64.rpm

elif [ '$osFlavor' == 'amazon' ]
then
wget https://downloads.mongodb.com/on-prem-mms/rpm/mongodb-mms-3.4.3.402-1.x86_64.rpm
sudo rpm -ivh mongodb-mms-3.4.3.402-1.x86_64.rpm
else 
wget https://downloads.mongodb.com/on-prem-mms/deb/mongodb-mms_3.4.3.402-1_x86_64.deb
sudo dpkg --install mongodb-mms_3.4.3.402-1_x86_64.deb
# update-rc.d: warning: start and stop actions are no longer supported; falling back to defaults
fi

# sudo vi /opt/mongodb/mms/conf/conf-mms.properties

# Goto this line and replace connection string 
# mongo.mongoUri=mongodb://127.0.0.1:27017/?maxPoolSize=150

cat /opt/mongodb/mms/conf/conf-mms.properties | sed 's#mongoUri=.*\$#mongoUri=mongodb://$rsAppDBUser:$rsAppDBPassword@${omgrPrivateDNS[0]}:$appDBPort,${omgrPrivateDNS[1]}:$appDBPort,${omgrPrivateDNS[2]}:$appDBPort/?authSource=admin\&replicaSet=$rsAppDBName\&maxPoolSize=150#g' | sudo tee /opt/mongodb/mms/conf/conf-mms.properties

INSHTTP


tee "$scriptsFolder/08.opsmgr.start.http.sh" <<STARTHTTP
############################################################
# Ops Manager: Start only one of the Server #1
# Server #1: ${omgrPublicDNS[0]} / ${omgrPrivateDNS[0]}
# Notes: Will take 5 mins. 
############################################################

# Upload the aws private key to the amazon instance 
# scp -i $awsPrivateKeyPath $awsPrivateKeyPath  $awsSSHUser@${omgrPublicDNS[0]}:/home/$awsSSHUser

sudo service mongodb-mms start

STARTHTTP

tee "$scriptsFolder/09.opsmgr.config.http.sh" <<CONFIGHTTP
############################################################
# Ops Manager: Conigure the Ops Manager via UI
############################################################
# http://${omgrPublicDNS[0]}:8080
# http://${omgrPrivateDNS[0]}:8080
# http://${omgrPublicDNS[0]}:8443
# http://${omgrPrivateDNS[0]}:8443
# Load Balancer configuration
# http://ska-clb-01-2076939081.us-west-2.elb.amazonaws.com:8080
# https://ska-clb-01-2076939081.us-west-2.elb.amazonaws.com
# AWS-LB > Health Check > :8080 | /user/login
# AWS-LB > Health Check > :8443 | /user/login
# X-Forwarded-For
# shyam.arjarapu@10gen.com ORS smtp.gmail.com

############################################################
# Ops Manager: Copy /etc/mongodb-mms/gen.key from Server #1 to #3
# Copy gen.key, start mms, create backup deamon folder
############################################################
sudo scp -i $awsPrivateKeyName /etc/mongodb-mms/gen.key  $awsSSHUser@${omgrPrivateDNS[2]}:/home/$awsSSHUser
# Run one by one accept the fingerprint before running beloe 
sudo scp -i $awsPrivateKeyName /etc/mongodb-mms/gen.key  $awsSSHUser@${omgrPrivateDNS[1]}:/home/$awsSSHUser


############################################################
# Configure Server #1 to #3 and start the mongodb-mms service
############################################################
sudo mv gen.key /etc/mongodb-mms/gen.key
sudo chown mongodb-mms:mongodb-mms /etc/mongodb-mms/gen.key
sudo service mongodb-mms start
CONFIGHTTP


tee "$scriptsFolder/10.opsmgr.config.backup.sh" <<CONFIGBACKUP

############################################################
# Filesystem Store: On Ops Manager HTTP Server # 1 & #3
############################################################
sudo mkdir -p /backup/fileSystemStore
sudo chown mongodb-mms:mongodb-mms /backup /backup/fileSystemStore


############################################################
# Backup Daemon: On Server #2 create headdb folder
# Server #3: ${omgrPrivateDNS[1]}
# Double check from UI
############################################################
sudo mkdir -p /backup/headdb
sudo chown mongodb-mms:mongodb-mms /backup /backup/headdb

# Ops Manager UI: Backup > configure the backup module
# /backup/headdb
# enable daemon
# /backup/fileSystemStore

# servers: ${omgrPrivateDNS[0]}:$oplogDBPort,${omgrPrivateDNS[1]}:$oplogDBPort,${omgrPrivateDNS[2]}:$oplogDBPort
# user: $rsOplogDBUser
# password: $rsOplogDBPassword
# options: authSource=admin&replicaSet=$rsOplogStoreName&maxPoolSize=150

# Install Backup Agent on the deployment 

CONFIGBACKUP


tee "$scriptsFolder/11.opsmgr.install.agents.sh" <<INSAGENTS
###############################################################
# Install Automation Agents
###############################################################
# i2cssh -Xi=~/.ssh/amazonaws_rsa -c aws_ors_mongo


if [ '$osFlavor' == 'ubuntu' ]
then
sudo apt-get update
binaryVersionWithExt='_3.2.10.1997-1_amd64.ubuntu1604.deb'
else
sudo yum -y upgrade 
binaryVersionWithExt='-3.2.10.1997-1.x86_64.rpm'
fi

opsmgrUri=${omgrPublicDNS[0]}
mmsGroupId=58a11019d0f6c8231193df72
mmsApiKey=be6793ccfb0a74b2b239650fa788367f

# what about the https ?
curl -k -OL http://\$opsmgrUri:8080/download/agent/automation/mongodb-mms-automation-agent-manager\$binaryVersionWithExt -k

if [ '$osFlavor' == 'ubuntu' ]
then
sudo dpkg -i mongodb-mms-automation-agent-manager\$binaryVersionWithExt
else
sudo rpm -U mongodb-mms-automation-agent-manager\$binaryVersionWithExt
fi


sudo cp /etc/mongodb-mms/automation-agent.config /tmp/automation-agent.orig.config
sudo sed "s/mmsGroupId=.*\$/mmsGroupId=\$mmsGroupId/g" /etc/mongodb-mms/automation-agent.config | \
    sed "s/mmsApiKey=.*\$/mmsApiKey=\$mmsApiKey/g" | \
    sed "s/mmsBaseUrl=.*\$/mmsBaseUrl=http:\/\/\$opsmgrUri:8080/g" | \
    tee /tmp/automation-agent.config
sudo -u $mongoUser cp /tmp/automation-agent.config /etc/mongodb-mms/automation-agent.config
sudo cat /etc/mongodb-mms/automation-agent.config

# sslTrustedMMSServerCertificate=/etc/ssl/rootCA.pem
# sslRequireValidMMSServerCertificates=false
# mongo --host ip-172-31-3-184.us-west-2.compute.internal --port 27000 --ssl --sslPEMKeyFile /etc/ssl/omgr.ska-clb-01-2076939081.us-west-2.elb.amazonaws.com.pem --sslCAFile /etc/ssl/rootCA.public.crt
# mongo --host ip-172-31-3-184.us-west-2.compute.internal --port 27000 --ssl --sslPEMKeyFile /etc/ssl/rootCA.pem --sslCAFile /etc/ssl/rootCA.public.crt
# sudo tcpdump -X -i ens3 'port 27000'
# sudo tcpdump -X -i lo0 'port 27017'
db.people.insert({ssn: 'you should not be looking at this secret stuff', text: 'other secret stuff in there'})

sudo mkdir -p $dataFolder
sudo chown $mongoUser:$mongoUser $dataFolder
sudo service mongodb-mms-automation-agent start
INSAGENTS


tee "$scriptsFolder/12.opsmgr.install.pool.sh" <<INSPOOL
###############################################################
# Pool: Install Automation Agents
###############################################################


if [ '$osFlavor' == 'ubuntu' ]
then
sudo apt-get update
binaryVersionWithExt='_3.2.10.1997-1_amd64.ubuntu1604.deb'
else
sudo yum -y upgrade 
binaryVersionWithExt='-3.2.10.1997-1.x86_64.rpm'
fi

opsmgrUri=${omgrPublicDNS[0]}
serverPoolKey=4e324700df392529b115cb2b992efb14
mmsApiKey=3136703d14c1919ee176180c2b5d7157

# i2cssh -Xi=~/.ssh/amazonaws_rsa -c aws_ors_pool
sudo yum -y upgrade 


curl -OL http://\$opsmgrUri:8080/download/agent/automation/mongodb-mms-automation-agent-manager\$binaryVersionWithExt -k

if [ '$osFlavor' == 'ubuntu' ]
then
sudo dpkg -i mongodb-mms-automation-agent-manager\$binaryVersionWithExt
else
sudo rpm -U mongodb-mms-automation-agent-manager\$binaryVersionWithExt
fi


sudo cp /etc/mongodb-mms/automation-agent.config /tmp/automation-agent.orig.config
sudo sed 's/serverPoolKey=/serverPoolKey=$serverPoolKey/g' /etc/mongodb-mms/automation-agent.config | \
    sed 's/mmsBaseUrl=/mmsBaseUrl=http:\/\/$opsmgrUri:8080/g' | \
    tee /tmp/automation-agent.config
sudo -u $mongoUser cp /tmp/automation-agent.config /etc/mongodb-mms/automation-agent.config
sudo cat /etc/mongodb-mms/automation-agent.config

# sslTrustedServerCertificates=/etc/ssl/rootCA.pem




# 1 MEDIUM across US-EAST, US-CENTRAL, US-WEST
# 3 LARGE across US-EAST
# Stopped: 1 Large instance
sudo -u $mongoUser tee /etc/mongodb-mms/server-pool.properties <<EOF 
Datacenter=US-EAST
Size=MEDIUM
EOF

sudo -u $mongoUser tee /etc/mongodb-mms/server-pool.properties <<EOF 
Datacenter=US-EAST
Size=LARGE
EOF

sudo -u $mongoUser vi /etc/mongodb-mms/server-pool.properties 

sudo mkdir -p $dataFolder
sudo chown $mongoUser:$mongoUser $dataFolder
sudo service mongodb-mms-automation-agent start

# regex  ip-172-31-13-163|ip-172-31-6-73|ip-172-31-8-94
INSPOOL


tee "$scriptsFolder/13.generate.backup.restore.data.sh" <<EOF
show dbs
use social 
show collections
for(var i = 0; i < 1000; i ++) { 
    db.persons.insert({fname: 'fname ' + i, createdOn: new Date()}); 
}
db.persons.count()

for(var i = 10000; i < 20000; i ++) { 
    db.persons.insert({fname: 'fname ' + i, createdOn: new Date()}); 
}

db.persons.count()

for(var i = 20000; i < 30000; i ++) { 
    db.persons.insert({fname: 'fname ' + i, createdOn: new Date()}); 
}

EOF


cat "$scriptsFolder/00.drive.creation.sh" "$scriptsFolder/01.opsmgr.appdb.install.sh" "$scriptsFolder/03.opsmgr.oplogdb.install.sh" "$scriptsFolder/06.opsmgr.oplogdb.initd.sh"  > "$scriptsFolder/99.01.opsmgr.appdb.oplogdb.install.sh" 
cat "$scriptsFolder/02.opsmgr.appdb.configrs.sh" "$scriptsFolder/04.opsmgr.oplogdb.configrs.sh" > "$scriptsFolder/99.02.opsmgr.appdb.oplogdb.configrs.sh" 
cat "$scriptsFolder/07.opsmgr.install.http.sh" "$scriptsFolder/08.opsmgr.start.http.sh" "$scriptsFolder/09.opsmgr.config.http.sh" "$scriptsFolder/10.opsmgr.config.backup.sh"  > "$scriptsFolder/99.03.opsmgr.configuration.sh" 




tee "$scriptsFolder/90.opsmgr.certificates2.sh" <<CERTS
###############################################################
# Create certificates required for Ops Manager demo 
###############################################################

# Generate the Certificate Authority
caCertsPath='$scriptsFolder/certs'
caPassword='secret_ca'
caServerName='${omgrPublicDNS[0]}'

# Generate the private root key file - this file should be kept secure:
openssl genrsa -des3 -passout pass:\$caPassword -out \$caCertsPath/rootCA.private.key 4096

# Generate the public root certificate - it is our CAFile that has to be distributed among the servers and clients so they could validate each other’s certificates
openssl req -x509 -new -days 365  -passin pass:\$caPassword -key \$caCertsPath/rootCA.private.key -out \$caCertsPath/rootCA.public.crt -subj "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Certification Authority/CN=\$caServerName"

# Signature: createCertificate <role:omgr,client,member1,kmipMember1> <FQDN> <PEM Password> <CA Password> <CN>
createCertificate()
{
    serverRole=\$1
    serverName=\$2
    serverPassword=\$3 
    caPassword=\$4
    subject=\$5

    caCertsPath='$scriptsFolder/certs'

    # Generate the private key file:
    openssl genrsa -des3 -passout pass:\$serverPassword -out \$caCertsPath/\$serverRole.\$serverName.private.key 4096 

    # Generate a Certificate Signing Request (CSR), ensure that the CN you specified matches the FQDN of the host
    openssl req -new -passin pass:\$serverPassword -key \$caCertsPath/\$serverRole.\$serverName.private.key -out \$caCertsPath/\$serverRole.\$serverName.csr -subj \$subject
    #  "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Operations/CN=\$serverName"

    # Use the CSR to create a certificate signed with our root certificate
    openssl x509 -req -passin pass:\$caPassword -in \$caCertsPath/\$serverRole.\$serverName.csr -CA \$caCertsPath/rootCA.public.crt -CAkey \$caCertsPath/rootCA.private.key -CAcreateserial -out \$caCertsPath/\$serverRole.\$serverName.public.crt -days 365


    # Concatenate them into a single .pem file - that is the PEMKeyFile option that should be used to start the mongod process
    cat \$caCertsPath/\$serverRole.\$serverName.private.key \$caCertsPath/\$serverRole.\$serverName.public.crt > \$caCertsPath/\$serverRole.\$serverName.pem
    
    # Verify that the .pem file can be validated with the root certificate that was used to sign it
    # That should return \$serverRole.\$serverName.pem: OK
    openssl verify -CAfile \$caCertsPath/rootCA.public.crt \$caCertsPath/\$serverRole.\$serverName.pem 
}


# Certificate: Ops Manager WebServer
createCertificate 'omgr' '${omgrPublicDNS[0]}' 'secret_omgr' "\$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Operations/CN=${omgrPublicDNS[0]}"

# Certificates: TLS for all members 
createCertificate 'member' '${mongoPrivateDNS[0]}' 'secret_member' "\$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Databases/CN=${mongoPrivateDNS[0]}"
createCertificate 'member' '${mongoPrivateDNS[1]}' 'secret_member' "\$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Databases/CN=${mongoPrivateDNS[1]}"
createCertificate 'member' '${mongoPrivateDNS[2]}' 'secret_member' "\$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Databases/CN=${mongoPrivateDNS[2]}"

# Certificate: Client
createCertificate 'client' '${omgrPrivateDNS[0]}' 'secret_client' "\$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Clients/CN=${omgrPrivateDNS[0]}"
createCertificate 'client' '${omgrPrivateDNS[1]}' 'secret_client' "\$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Clients/CN=${omgrPrivateDNS[1]}"
createCertificate 'client' '${omgrPrivateDNS[2]}' 'secret_client' "\$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Clients/CN=${omgrPrivateDNS[2]}"

# Certificate: Super User 
superUser="/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Users/CN=${omgrPrivateDNS[0]}"
createCertificate 'user' '${omgrPrivateDNS[0]}' 'secret_user' "\$caPassword" \$superUser

# create 
userCN=\$( openssl x509 -in  ./scripts/certs/user.${omgrPrivateDNS[0]}.pem  -inform PEM -subject -nameopt RFC2253 -noout | cut -d' ' -f2 )



################################################################################
# Localhost testing 
################################################################################
# Certificates: TLS for all members 
createCertificate 'member' 'server1.arjarapu.net' 'secret_member' "\$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Databases/CN=server1.arjarapu.net"
createCertificate 'member' 'server2.arjarapu.net' 'secret_member' "\$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Databases/CN=server2.arjarapu.net"
createCertificate 'member' 'server3.arjarapu.net' 'secret_member' "\$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Databases/CN=server3.arjarapu.net"

# Certificate: Client
createCertificate 'client' 'client.arjarapu.net' 'secret_client' "\$caPassword" "/C=US/ST=Texas/L=Austin/O=MongoDB/OU=Clients/CN=client.arjarapu.net"







echo "openssl x509 -in client.pem -inform PEM -subject -nameopt RFC2253 -noout"
echo "use admin; db.getSiblingDB('\\\$external').runCommand({createUser: \$superUser, roles: [{role: 'root', db: 'admin'}]})"
echo "use admin; db.getSiblingDB('\\\$external').auth({user: \$superUser, mechanism: 'MONGODB-X509'})"

echo "Client Certificate Mode * ** "
echo "scp -i $awsPrivateKeyPath \$caCertsPath/omgr.${omgrPublicDNS[0]}.pem  $awsSSHUser@${omgrPublicDNS[0]}:/home/$awsSSHUser"
echo "scp -i $awsPrivateKeyPath \$caCertsPath/omgr.${omgrPublicDNS[1]}.pem  $awsSSHUser@${omgrPublicDNS[1]}:/home/$awsSSHUser"
echo "scp -i $awsPrivateKeyPath \$caCertsPath/omgr.${omgrPublicDNS[2]}.pem  $awsSSHUser@${omgrPublicDNS[2]}:/home/$awsSSHUser"

echo "scp -i $awsPrivateKeyPath \$caCertsPath/rootCA.public.crt  $awsSSHUser@${omgrPublicDNS[0]}:/home/$awsSSHUser"
echo "scp -i $awsPrivateKeyPath \$caCertsPath/rootCA.public.crt  $awsSSHUser@${omgrPublicDNS[1]}:/home/$awsSSHUser"
echo "scp -i $awsPrivateKeyPath \$caCertsPath/rootCA.public.crt  $awsSSHUser@${omgrPublicDNS[2]}:/home/$awsSSHUser"

echo "sudo mv omgr.\$serverName.pem /etc/security/opsmanager.pem"
echo "X-Forwarded-For"

CERTS




tee "$scriptsFolder/15.mongodb.production.notes.sh" <<NOTES
###############################################################
# Production Notes scripts for all mongods 
# ulimit: sudo sh -c 'ulimit -a' -e mongodb
# NUMA:  sudo cat /proc/sys/vm/zone_reclaim_mode
# TCP: sudo cat /proc/sys/net/ipv4/tcp_keepalive_time
# THP: sudo cat /sys/kernel/mm/transparent_hugepage/enabled 
# sudo cat /sys/kernel/mm/transparent_hugepage/defrag
###############################################################

# sudo cat /etc/security/limits.conf
echo "
*     soft     nofile     64000
*     hard     nofile     64000
*     -        fsize      unlimited
*     -        cpu        unlimited
*     hard     rss        unlimited
" | sudo tee -a /etc/security/limits.conf


# sudo cat /etc/sysctl.conf
echo "
net.ipv4.tcp_keepalive_time = 120
vm.zone_reclaim_mode = 0
vm.nr_hugepages = 0
vm.nr_hugepages_mempolicy = 0
" | sudo tee -a /etc/sysctl.conf

# sudo cat /etc/rc.local
echo "
for i in /sys/kernel/mm/*transparent_hugepage/enabled; do echo never > $i; done
for i in /sys/kernel/mm/*transparent_hugepage/defrag; do echo never > $i; done
exit 0;
blockdev --setra 0 /dev/xvda
" | sudo tee -a /etc/rc.local


NOTES





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
sudo chown $mongoUser:$mongoUser $dataFolder $dataFolder/db

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
sudo chown $mongoUser:$mongoUser /etc/mongod.conf

sudo -u $mongoUser sh -c 'echo $rsAppDBPasswordsaltprogresoReplSet | openssl sha1 -sha512  | sed 's/(stdin)= //g' > $dataFolder/keyfile'
sudo -u $mongoUser sh -c 'chmod 400 $dataFolder/keyfile'
sudo -u $mongoUser /usr/bin/mongod --config /etc/mongod.conf 
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

use admin 
db.createUser({user: 'mms-automation', pwd: 'secret_auto', roles: ['clusterAdmin', 'dbAdminAnyDatabase', 'readWriteAnyDatabase', 'restore', 'userAdminAnyDatabase']})


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
openssl rand -base64 32 | sed 's#[+=/]##g' | sudo tee /etc/security/mongodb-encryption-keyfile

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
sudo chown $mongoUser:$mongoUser $dataFolder
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
sudo -u $mongoUser sh -c 'ulimit -a'
numactl --hardware
sysctl net.ipv4.tcp_keepalive_time
sudo sysctl vm.zone_reclaim_mode

# can you run it on the device where your $mongoUser is installing 
# sudo blockdev --getra /dev/xvda



sudo mv /etc/rc.d/init.d/mongod /etc/rc.d/init.d/mongod-appdb
sudo cp /etc/rc.d/init.d/mongod-appdb /etc/rc.d/init.d/mongod-oplogstore


sudo -u $mongoUser sh -c 'sed -i  's#/etc/mongod.conf#$dataFolder/appdb/mongod.conf#g' /etc/rc.d/init.d/mongod-appdb'
sudo -u $mongoUser sed -i  's#/etc/mongod.conf#$dataFolder/oplogstore/mongod.conf#g' /etc/rc.d/init.d/mongod-oplogstore

sudo chown $mongoUser -R $dataFolder
sudo chown $mongoUser -R  /var/log/mongodb-mms-automation
sudo chown $mongoUser -R  /var/lib/mongodb-mms-automation

nohup sudo -u $mongoUser ./mongodb-mms-automation-agent --config=local.config >> /var/log/mongodb-mms-automation/automation-agent.log 2>&1 &


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


# Removing 
# sudo update-rc.d -f mongod-oplogstore remove
# sudo rm /etc/init.d/mongod-oplogstore
# sudo service --status-all | grep mongo
# sudo curl https://raw.githubusercontent.com/mongodb/mongo/master/debian/init.d --output /tmp/mongod-oplogstore.initd
sudo curl https://github.com/mongodb/mongo/blob/master/debian/mongod.service --output /tmp/mongod-oplogstore.service

sudo cat /tmp/mongod-oplogstore.service | \
    sed 's#CONF=/etc/mongod.conf#CONF=/etc/mongod-oplogstore.conf#g' | \
    sed 's#NAME=mongod#NAME=mongod-oplogstore#g' | \
    sed 's/# Provides:          mongod/# Provides:          mongod-oplogstore/g' | \
    sudo tee /etc/init.d/mongod-oplogstore

cat /lib/systemd/system/mongod.service | \
    sed 's#mongod.conf#mongod-oplogstore.conf#g' | \
    sudo tee /lib/systemd/system/mongod-oplogstore.service


sudo chmod 755 /etc/init.d/mongod-oplogstore
sudo update-rc.d mongod-oplogstore defaults
# systemctl status mongod-oplogstore.service


OTHER

# scp -i $awsPrivateKeyPath $awsPrivateKeyPath  $awsSSHUser@${omgrPublicDNS[0]}:/home/$awsSSHUser


