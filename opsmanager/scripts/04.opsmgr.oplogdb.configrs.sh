############################################################
# Backup DB: Configure MongoDB ReplicaSet
# Run only on Server #2: ip-172-31-45-56.us-west-2.compute.internal
############################################################

mongo --port 27001 <<EOF
use admin
rs.initiate({_id: 'rsOplogStore', 'members' : [{ '_id' : 0, 'host' : 'ip-172-31-41-82.us-west-2.compute.internal:27001'}]})
sleep(10000)
db.createUser({user: 'superuser', pwd: 'secret', roles: ['root']})
db.auth('superuser', 'secret')

rs.add({ host: 'ip-172-31-45-56.us-west-2.compute.internal:27001', priority: 5 })
rs.add({ host: 'ip-172-31-46-255.us-west-2.compute.internal:27001' })
sleep(3000)
EOF
