show dbs
use social 
show collections
for(var i = 0; i < 1000; i ++) { 
    db.persons.insert({fname: 'fname ' + i, createdOn: new Date()}); 
    sleep(10) 
}
db.persons.count()
