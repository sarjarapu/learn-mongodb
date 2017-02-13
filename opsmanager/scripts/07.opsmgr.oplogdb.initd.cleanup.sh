############################################################
# Backup DB: Create the init.d startup scripts 
############################################################
if [ 'amzl' == 'rhel' ]
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
