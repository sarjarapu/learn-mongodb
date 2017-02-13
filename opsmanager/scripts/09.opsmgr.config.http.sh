############################################################
# Ops Manager: Conigure the Ops Manager via UI
############################################################
# http://ec2-54-186-26-151.us-west-2.compute.amazonaws.com:8080
# http://ip-172-31-2-131.us-west-2.compute.internal:8080
# shyam.arjarapu@10gen.com ORS smtp.gmail.com

############################################################
# Ops Manager: Copy /etc/mongodb-mms/gen.key from Server #1 to #3
# Copy gen.key, start mms, create backup deamon folder
############################################################
sudo scp -i amazonaws_rsa /etc/mongodb-mms/gen.key  ec2-user@ip-172-31-1-41.us-west-2.compute.internal:/home/ec2-user
sudo scp -i amazonaws_rsa /etc/mongodb-mms/gen.key  ec2-user@ip-172-31-11-109.us-west-2.compute.internal:/home/ec2-user


############################################################
# Configure Server #1 to #3 and start the mongodb-mms service
############################################################
sudo mv gen.key /etc/mongodb-mms/gen.key
sudo chown mongodb-mms:mongodb-mms /etc/mongodb-mms/gen.key
sudo service mongodb-mms start
