############################################################
# Ops Manager: Install HTTP Service
# Server #1: {
# Server #3: [
# https://docs.opsmanager.mongodb.com/current/tutorial/install-on-prem-with-rpm-packages/
############################################################
if [ 'amzl' == 'rhel' ]
then
sudo yum install -y wget
fi

wget https://downloads.mongodb.com/on-prem-mms/rpm/mongodb-mms-3.4.1.385-1.x86_64.rpm
sudo rpm -ivh mongodb-mms-3.4.1.385-1.x86_64.rpm
# sudo vi /opt/mongodb/mms/conf/conf-mms.properties

# Goto this line and replace connection string 
# mongo.mongoUri=mongodb://127.0.0.1:27017/?maxPoolSize=150

cat /opt/mongodb/mms/conf/conf-mms.properties | sed 's#mongoUri=.*$#mongoUri=mongodb://superuser:secret@{:27000,"Reservations"::27000,[:27000/?authSource=admin\&replicaSet=rsAppDB\&maxPoolSize=150#g' | sudo tee /opt/mongodb/mms/conf/conf-mms.properties

