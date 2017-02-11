############################################################
# Ops Manager DB: Configure MongoDB ReplicaSet
# Run only on Server #1: ec2-54-187-113-176.us-west-2.compute.amazonaws.com / ip-172-31-13-191.us-west-2.compute.internal
############################################################

mongo --port 27000 <<EOF
use admin
rs.initiate({_id: "rsAppDB", "members" : [{ "_id" : 0, "host" : "ip-172-31-13-191.us-west-2.compute.internal:27000"}]})
sleep(10000)
db.createUser({user: 'superuser', pwd: 'secret', roles: ['root']})
db.auth('superuser', 'secret')
rs.add('ip-172-31-11-91.us-west-2.compute.internal:27000')
rs.add('ip-172-31-14-48.us-west-2.compute.internal:27000')
EOF
