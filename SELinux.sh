
cat /etc/mongod.conf | grep -v '^$' | grep -v '#'
# Log: /var/log/mongodb/mongod.log
# Data: /var/lib/mongo

# SELinux: 
ls -lZa /var/lib/mongo
# drwxr-xr-x. mongod mongod system_u:object_r:mongod_var_lib_t:s0 .

ls -lZa /var/log/mongodb
# drwxr-xr-x. mongod mongod system_u:object_r:mongod_log_t:s0 .


sudo systemctl start mongod

ls -lZa /var/lib/mongo
ls -lZa /var/log/mongodb

sudo systemctl stop mongod


sudo vi /etc/mongod.conf
# path: /mnt/mongodb/log/mongod.log
# dbPath: /mnt/mongodb/data

sudo mkdir -p  /mnt/mongodb/{data,log}
ls -laZ /mnt/mongodb/
# drwxr-xr-x. root root unconfined_u:object_r:default_t:s0 .

sudo chown -R mongod:mongod /mnt/mongodb
sudo chcon -t mongod_log_t /mnt/mongodb/log
sudo chcon -t mongod_var_lib_t /mnt/mongodb/data