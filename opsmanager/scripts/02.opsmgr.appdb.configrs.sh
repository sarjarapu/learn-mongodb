############################################################
# Ops Manager DB: Configure MongoDB ReplicaSet
# Run only on Server #1: ip-172-31-41-82.us-west-2.compute.internal
############################################################

mongo --port 27000 <<EOF
use admin
rs.initiate({_id: 'rsAppDB', 'members' : [{ '_id' : 0, 'host' : 'ip-172-31-41-82.us-west-2.compute.internal:27000', priority: 5 }]})
sleep(10000)
db.createUser({user: 'superuser', pwd: 'secret', roles: ['root']})
db.auth('superuser', 'secret')
rs.add({ host: 'ip-172-31-45-56.us-west-2.compute.internal:27000' })
rs.add({ host: 'ip-172-31-46-255.us-west-2.compute.internal:27000' })
EOF
