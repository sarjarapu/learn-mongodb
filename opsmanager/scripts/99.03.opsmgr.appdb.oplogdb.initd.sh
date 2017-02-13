############################################################
# Ops Manager DB: Create the init.d startup scripts 
############################################################

sudo chown -R mongod:mongod /data

if [ 'amzl' == 'rhel' ]
then
sudo curl https://raw.githubusercontent.com/mongodb/mongo/master/rpm/mongod.service --output /tmp/mongod.service

cat /tmp/mongod.service |     sed 's#/etc/mongod.conf#/data/appdb/mongod.conf#g' |     sed 's#/var/run/mongodb#/data/appdb#g' |     sed 's# -p /data/appdb# -p /data/appdb/db#g' |     sed 's/mongod.pid/mongod-appdb.pid/g' |     sed 's#Description=.*#Description=Ops Manager MongoDB instance for AppDB#g' |     sudo tee /lib/systemd/system/mongod-appdb.service

sudo chcon -vR --user=system_u --type=mongod_var_lib_t /data/appdb
sudo chcon -v --user=system_u --type=mongod_unit_file_t /lib/systemd/system/mongod-appdb.service

sudo systemctl enable mongod-appdb.service 
sudo systemctl start mongod-appdb.service 

else
# Amazon Linux init.d scripts works. Delete /data/appdata/mongod.pid file if it doesnt 
sed 's#/etc/mongod.conf#/data/appdb/mongod.conf#g' /etc/init.d/mongod | sudo tee /etc/init.d/mongod-appdb
sudo chmod +x /etc/init.d/mongod-appdb
sudo chkconfig --add mongod-appdb
sudo chkconfig mongod-appdb on
sudo service mongod-appdb restart
fi

############################################################
# Backup DB: Create the init.d startup scripts 
############################################################
if [ 'amzl' == 'rhel' ]
then
sudo curl https://raw.githubusercontent.com/mongodb/mongo/master/rpm/mongod.service --output /tmp/mongod.service

cat /tmp/mongod.service |     sed 's#/etc/mongod.conf#/data/oplogstore/mongod.conf#g' |     sed 's#/var/run/mongodb#/data/oplogstore#g' |     sed 's# -p /data/oplogstore# -p /data/oplogstore/db#g' |     sed 's#Description=.*#Description=Ops Manager MongoDB instance for OplogStore#g' |     sudo tee /lib/systemd/system/mongod-oplogstore.service

sudo chcon -vR --user=system_u --type=mongod_var_lib_t /data/oplogstore
sudo chcon -v --user=system_u --type=mongod_unit_file_t /lib/systemd/system/mongod-oplogstore.service

sudo systemctl enable mongod-oplogstore.service 
sudo systemctl start mongod-oplogstore.service 

else
# Amazon Linux init.d scripts works. Delete /data/oplogstore/mongod.pid file if it doesnt 
sed 's#/etc/mongod.conf#/data/oplogstore/mongod.conf#g' /etc/init.d/mongod | sudo tee /etc/init.d/mongod-oplogstore
sudo chmod +x /etc/init.d/mongod-oplogstore
sudo chkconfig --add mongod-oplogstore
sudo chkconfig mongod-oplogstore on
sudo service mongod-oplogstore restart
fi

