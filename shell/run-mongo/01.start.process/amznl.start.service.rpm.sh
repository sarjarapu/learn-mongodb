#!/bin/sh

# Configure yum repository
echo "[mongodb-enterprise]
name=MongoDB Enterprise Repository
baseurl=https://repo.mongodb.com/yum/amazon/2013.03/mongodb-enterprise/3.4/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.4.asc" | sudo tee /etc/yum.repos.d/mongodb-enterprise.repo

	
# Install the MongoDB Enterprise packages and associated tools.
sudo yum install -y mongodb-enterprise

# create required folders, change owner on them 
sudo mkdir -p /data/db
sudo chown -R mongod:mongod /data

# Start the mongod service 
sudo service mongod start
