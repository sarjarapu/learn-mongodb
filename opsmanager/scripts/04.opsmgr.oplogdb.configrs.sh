############################################################
# Backup DB: Configure MongoDB ReplicaSet
# Run only on Server #2: "Reservations":
############################################################

mongo --port 27001 <<EOF
use admin
rs.initiate({_id: 'rsOplogStore', 'members' : [{ '_id' : 0, 'host' : '{:27001'}]})
sleep(10000)
db.createUser({user: 'superuser', pwd: 'secret', roles: ['root']})
db.auth('superuser', 'secret')

rs.add({ host: '"Reservations"::27001', priority: 5 })
rs.add({ host: '[:27001' })
sleep(3000)
EOF
