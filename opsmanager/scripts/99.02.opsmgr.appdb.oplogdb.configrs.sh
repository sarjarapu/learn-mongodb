############################################################
# Ops Manager DB: Configure MongoDB ReplicaSet
# Run only on Server #1: ip-172-31-6-17.us-west-2.compute.internal
############################################################

mongo --port 27000 <<EOF
use admin
rs.initiate({_id: 'rsAppDB', 'members' : [{ '_id' : 0, 'host' : 'ip-172-31-6-17.us-west-2.compute.internal:27000', priority: 5 }]})
sleep(10000)
db.createUser({user: 'superuser', pwd: 'secret', roles: ['root']})
db.auth('superuser', 'secret')
rs.add({ host: 'ip-172-31-8-235.us-west-2.compute.internal:27000' })
rs.add({ host: 'ip-172-31-9-51.us-west-2.compute.internal:27000' })
EOF
############################################################
# Backup DB: Configure MongoDB ReplicaSet
# Run only on Server #2: ip-172-31-8-235.us-west-2.compute.internal
############################################################

mongo --port 27001 <<EOF
use admin
rs.initiate({_id: 'rsOplogStore', 'members' : [{ '_id' : 0, 'host' : 'ip-172-31-6-17.us-west-2.compute.internal:27001'}]})
sleep(10000)
db.createUser({user: 'superuser', pwd: 'secret', roles: ['root']})
db.auth('superuser', 'secret')

rs.add({ host: 'ip-172-31-8-235.us-west-2.compute.internal:27001', priority: 5 })
rs.add({ host: 'ip-172-31-9-51.us-west-2.compute.internal:27001' })
sleep(3000)
EOF
