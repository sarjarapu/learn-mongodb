#!/bin/sh

# download the tar file, extract and copy 
curl -O https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-3.4.1.tgz
tar -zxvf mongodb-linux-x86_64-3.4.1.tgz
sudo mkdir /usr/lib/mongodb
sudo cp -R -n ~/mongodb-linux-x86_64-3.4.1/* /usr/lib/mongodb

# create the mongodb soft link in /usr/bin
sudo ln -s /usr/lib/mongodb/bin/mongod /usr/bin/mongod
sudo ln -s /usr/lib/mongodb/bin/mongo /usr/bin/mongo

# create required folders, mongod user and change owner on them 
sudo mkdir -p /var/log/mongodb /var/lib/mongo /var/run/mongodb /data/db
sudo useradd -r mongod
sudo chown -R mongod:mongod /data /var/log/mongodb /var/lib/mongo

# download the config and service files 
sudo curl https://raw.githubusercontent.com/mongodb/mongo/master/rpm/mongod.conf --output /etc/mongod.conf
sudo curl https://raw.githubusercontent.com/mongodb/mongo/master/rpm/mongod.service --output /lib/systemd/system/mongod.service

# Enable & start the mongod service
cd /lib/systemd/system/
sudo systemctl enable mongod.service 
sudo systemctl start mongod.service 

# Verify that the process is up and running 
sleep 2 
ps -ef | grep mongod
sudo systemctl status mongod.service 




