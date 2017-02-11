############################################################
# Backup DB: Configure MongoDB ReplicaSet
# Run only on Server #2: ip-172-31-11-91.us-west-2.compute.internal
############################################################

mongo --port 27001 <<EOF
use admin
rs.initiate({_id: "rsOplogStore", "members" : [{ "_id" : 0, "host" : "ip-172-31-11-91.us-west-2.compute.internal:27001"}]})
sleep(10000)
db.createUser({user: 'superuser', pwd: 'secret', roles: ['root']})
db.auth('superuser', 'secret')

rs.add('ip-172-31-13-191.us-west-2.compute.internal:27001')
rs.add('ip-172-31-14-48.us-west-2.compute.internal:27001')
sleep(3000)
EOF
