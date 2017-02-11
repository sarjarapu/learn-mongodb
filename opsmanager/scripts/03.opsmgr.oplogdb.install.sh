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
security:
   authorization: enabled
   keyFile: /data/oplogstore/keyfile
EOF

sudo -u mongod sh -c "echo secretsaltOplogStore | openssl sha1 -sha512  | sed 's/(stdin)= //g' > /data/oplogstore/keyfile"
sleep 1
sudo -u mongod sh -c "chmod 400 /data/oplogstore/keyfile"
sudo -u mongod /usr/bin/mongod --config /data/oplogstore/mongod.conf 
sleep 2
