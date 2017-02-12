############################################################
# Ops Manager: Conigure the Ops Manager via UI
############################################################
# http://ec2-54-202-43-118.us-west-2.compute.amazonaws.com:8080
# http://{:8080
# shyam.arjarapu@10gen.com ORS smtp.gmail.com

############################################################
# Ops Manager: Copy /etc/mongodb-mms/gen.key from Server #1 to #3
# Copy gen.key, start mms, create backup deamon folder
############################################################
scp -i ~/.ssh/amazonaws_rsa ~/.ssh/amazonaws_rsa  ec2-user@ec2-54-202-43-118.us-west-2.compute.amazonaws.com:/home/ec2-user
sudo scp -i amazonaws_rsa /etc/mongodb-mms/gen.key  ec2-user@[:/home/ec2-user
sudo scp -i amazonaws_rsa /etc/mongodb-mms/gen.key  ec2-user@"Reservations"::/home/ec2-user

sudo mv gen.key /etc/mongodb-mms/gen.key
sudo chown mongodb-mms:mongodb-mms /etc/mongodb-mms/gen.key
sudo service mongodb-mms start

############################################################
# Filesystem Store: On Ops Manager HTTP Server # 1 & #3
############################################################
sudo mkdir -p /backup/fileSystemStore
sudo chown mongodb-mms:mongodb-mms /backup /backup/fileSystemStore
