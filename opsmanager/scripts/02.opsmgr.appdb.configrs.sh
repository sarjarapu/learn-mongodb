############################################################
# Ops Manager DB: Configure MongoDB ReplicaSet
# Run only on Server #1: {
############################################################

mongo --port 27000 <<EOF
use admin
rs.initiate({_id: 'rsAppDB', 'members' : [{ '_id' : 0, 'host' : '{:27000', priority: 5 }]})
sleep(10000)
db.createUser({user: 'superuser', pwd: 'secret', roles: ['root']})
db.auth('superuser', 'secret')
rs.add({ host: '"Reservations"::27000' })
rs.add({ host: '[:27000' })
EOF
