#!/bin/sh
cd ../ansible

# # create aws instances for the mongodb servers
# ansible-playbook create.instances.yml

# # # Wait for 2/2 Status Checks
# # sleep 300

# configure the mongodb replicaset 
ansible-playbook create.replicaset.yml
