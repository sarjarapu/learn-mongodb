############################################################
# Backup Daemon: On Server #3 create headdb folder
# Server #3: [
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
# servers: {:27001,"Reservations"::27001,[:27001
# options: authSource=admin&replicaSet=rsOplogStore&maxPoolSize=150
