
############################################################
# Filesystem Store: On Ops Manager HTTP Server # 1 & #3
############################################################
sudo mkdir -p /backup/fileSystemStore
sudo chown mongodb-mms:mongodb-mms /backup /backup/fileSystemStore


############################################################
# Backup Daemon: On Server #3 create headdb folder
# Server #3: ip-172-31-1-41.us-west-2.compute.internal
# Double check from UI
############################################################
sudo mkdir -p /backup/headdb
sudo chown mongodb-mms:mongodb-mms /backup /backup/headdb

# Ops Manager UI: Backup > configure the backup module
# /backup/headdb
# enable daemon
# /backup/fileSystemStore

# servers: ip-172-31-2-131.us-west-2.compute.internal:27001,ip-172-31-11-109.us-west-2.compute.internal:27001,ip-172-31-1-41.us-west-2.compute.internal:27001
# user: superuser
# password: secret
# options: authSource=admin&replicaSet=rsOplogStore&maxPoolSize=150

# Install Backup Agent on the deployment 

