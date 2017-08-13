#!/bin/sh 

cat mongodb.log | grep '2017-08-09T' | grep -v 'connections now open' | grep -v 'signalProcessingThread' | grep -v 'ACCESS' | grep -v 'NETWORK' | grep -v 'pthread_create' | grep -v 'failed to create service' | grep -v 'local.oplog.rs' > mongodb.queries.log

mkdir analyze
grep 'keysExamined' mongodb.queries.log > analyze/mongod.keysexamined.log
grep 'timeAcquiringMicros' mongodb.queries.log > analyze/mongod.acquiringmicros.log
grep 'unwind' mongodb.queries.log > analyze/mongod.unwind.log
grep 'inserts' mongodb.queries.log > analyze/mongod.inserts.log

# queries with nreturned
cat  mongod.keysexamined.log | grep COMMAND | sed -E 's#([0-9T\:Z]+) .+command: ([a-zA-Z]+) .+keysExamined:([0-9]+) docsExamined:([0-9]+) .*nreturned:([0-9]+) .* timeAcquiringMicros: \{ r: ([^,]+) \} \}, .+ ([0-9]+)ms#\1|\2|\3|\4|\5|\6|\7#g' > temp.mkeq.log
# for logs that do not have timeAcquiringMicros
cat  temp.mkeq.log | sed -E 's#([0-9T\:Z]+) .+command: ([a-zA-Z]+) .+keysExamined:([0-9]+) docsExamined:([0-9]+) .*nreturned:([0-9]+) .+ ([0-9]+)ms#\1|\2|\3|\4|\5|-1|\6#g' > temp.mkea.log
# for logs that do not have nreturned
cat temp.mkea.log | sed -E 's#([0-9T\:Z]+) .+command: ([a-zA-Z]+) .+keysExamined:([0-9]+) docsExamined:([0-9]+) .* timeAcquiringMicros: \{ r: ([^,]+) \} \}, .+ ([0-9]+)ms#\1|\2|\3|\4|1|\5|\6#g' > temp.mker.log
#  for logs that do not have nreturned and timeAcquiringMicros
cat temp.mker.log | sed -E 's#([0-9T\:Z]+) .+command: ([a-zA-Z]+) .+keysExamined:([0-9]+) docsExamined:([0-9]+) .* ([0-9]+)ms#\1|\2|\3|\4|1|-1|\5#g' > temp.mkera.log
echo "date|time|command|keysExamined|docsExamined|nreturned|timeAcquiringMicros|ms\n" > temp.mkoutput.log
cat temp.mkera.log | sed -E 's/^([0-9\-]+)T([0-9:\.]+)Z/\1|\2/g' >> temp.mkoutput.log
gsed 's/|/\t/g' temp.mkoutput.log > mongod.keysexamined.output.log
cat mongod.keysexamined.output.log | pbcopy
# date time command keysExamined docsExamined nreturned timeAcquiringMicros ms 
rm temp.mk*.log 



