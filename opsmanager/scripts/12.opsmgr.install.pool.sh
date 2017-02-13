###############################################################
# Pool: Install Automation Agents
###############################################################

opsmgrUri=ec2-54-149-235-81.us-west-2.compute.amazonaws.com
rpmVersion=3.2.8.1942-1.x86_64
serverPoolKey=4e324700df392529b115cb2b992efb14
mmsApiKey=3136703d14c1919ee176180c2b5d7157

i2cssh -Xi=~/.ssh/amazonaws_rsa -c aws_ors_pool
sudo yum -y upgrade 

curl -OL http://:8080/download/agent/automation/mongodb-mms-automation-agent-manager-3.2.8.1942-1.x86_64.rpm
sudo rpm -U mongodb-mms-automation-agent-manager-.rpm

sudo cp /etc/mongodb-mms/automation-agent.config /tmp/automation-agent.orig.config
sudo sed 's/serverPoolKey=/serverPoolKey=/g' /etc/mongodb-mms/automation-agent.config |     sed 's/mmsBaseUrl=/mmsBaseUrl=http:\/\/:8080/g' |     tee /tmp/automation-agent.config
sudo -u mongod cp /tmp/automation-agent.config /etc/mongodb-mms/automation-agent.config
sudo cat /etc/mongodb-mms/automation-agent.config


# 1 MEDIUM across US-EAST, US-CENTRAL, US-WEST
# 3 LARGE across US-EAST
# Stopped: 1 Large instance
sudo -u mongod tee /etc/mongodb-mms/server-pool.properties <<EOF 
Datacenter=US-EAST
Size=MEDIUM
EOF

sudo -u mongod tee /etc/mongodb-mms/server-pool.properties <<EOF 
Datacenter=US-EAST
Size=LARGE
EOF

sudo -u mongod vi /etc/mongodb-mms/server-pool.properties 

sudo mkdir -p /data
sudo chown mongod:mongod /data
sudo service mongodb-mms-automation-agent start

# regex  ip-172-31-13-163|ip-172-31-6-73|ip-172-31-8-94
