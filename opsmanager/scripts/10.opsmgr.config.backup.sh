############################################################
# Backup Daemon: On Server #3 create headdb folder
# Server #3: ip-172-31-14-48.us-west-2.compute.internal
# Double check from UI
############################################################
sudo mkdir -p /backup/headdb
sudo chown mongodb-mms:mongodb-mms /backup /backup/headdb

# Ops Manager UI: Backup > configure the backup module
# /backup/headdb
# enable daemon
# /backup/fileSystemStore

# user: superuser
# password: secret
# servers: ip-172-31-13-191.us-west-2.compute.internal:27001,ip-172-31-11-91.us-west-2.compute.internal:27001,ip-172-31-14-48.us-west-2.compute.internal:27001
# options: authSource=admin&replicaSet=rsOplogStore&maxPoolSize=150
