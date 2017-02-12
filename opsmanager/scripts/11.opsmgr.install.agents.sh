###############################################################
# Install Automation Agents
###############################################################
i2cssh -Xi=~/.ssh/amazonaws_rsa -c aws_ors_mongo
sudo yum -y upgrade 

opsmgrUri=ec2-54-202-43-118.us-west-2.compute.amazonaws.com
rpmVersion=3.2.8.1942-1.x86_64
mmsGroupId=589cfc39dd9b172290a751c2
mmsApiKey=56d23d836b0ba6c55e368a853e86de63


curl -OL http://$opsmgrUri:8080/download/agent/automation/mongodb-mms-automation-agent-manager-$rpmVersion.rpm
sudo rpm -U mongodb-mms-automation-agent-manager-$rpmVersion.rpm

sudo cp /etc/mongodb-mms/automation-agent.config /tmp/automation-agent.orig.config
sudo sed 's/mmsGroupId=.*$/mmsGroupId=$mmsGroupId/g' /etc/mongodb-mms/automation-agent.config |     sed 's/mmsApiKey=.*$/mmsApiKey=$mmsApiKey/g' |     sed 's/mmsBaseUrl=.*$/mmsBaseUrl=http:\/\/$opsmgrUri:8080/g' |     tee /tmp/automation-agent.config
sudo -u mongod cp /tmp/automation-agent.config /etc/mongodb-mms/automation-agent.config
sudo cat /etc/mongodb-mms/automation-agent.config

sudo mkdir -p /data
sudo chown mongod:mongod /data
sudo service mongodb-mms-automation-agent start
