############################################################
# Ops Manager: Start only one of the Server #1
# Server #1: ec2-54-186-26-151.us-west-2.compute.amazonaws.com / ip-172-31-2-131.us-west-2.compute.internal
# Notes: Will take 5 mins. 
############################################################

# Upload the aws private key to the amazon instance 
# scp -i ~/.ssh/amazonaws_rsa ~/.ssh/amazonaws_rsa  ec2-user@ec2-54-186-26-151.us-west-2.compute.amazonaws.com:/home/ec2-user

sudo service mongodb-mms start

