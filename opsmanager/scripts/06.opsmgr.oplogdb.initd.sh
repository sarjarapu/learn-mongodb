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
sed 's#/etc/mongod.conf#/data/oplogstore/mongod.conf#g' /etc/init.d/mongod | sudo tee /etc/init.d/mongod-oplogstore
sudo chown mongod:mongod /etc/init.d/mongod-oplogstore
sudo chmod +x /etc/init.d/mongod-oplogstore
sudo chkconfig --add mongod-oplogstore
sudo chkconfig mongod-oplogstore on
sudo service mongod-appdb restart
fi

