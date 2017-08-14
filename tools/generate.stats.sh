#!/bin/sh 

cat mongodb.log | grep '2017-08-09T' | grep -v 'connections now open' | grep -v 'signalProcessingThread' | grep -v 'ACCESS' | grep -v 'NETWORK' | grep -v 'pthread_create' | grep -v 'failed to create service' | grep -v 'local.oplog.rs' | grep -v 'local.system.replset' > mongodb.queries.log

mkdir analyze
grep 'keysExamined' mongodb.queries.log > analyze/mongod.keysexamined.log
grep 'timeAcquiringMicros' mongodb.queries.log > analyze/mongod.acquiringmicros.log
grep 'unwind' mongodb.queries.log > analyze/mongod.unwind.log
grep 'inserts' mongodb.queries.log > analyze/mongod.inserts.log

# 2017-08-09T20:11:22.937Z I WRITE    [conn33944] update sledge.endpoint_firewall_statuses query:
# 2017-08-09T00:00:17.295Z I COMMAND  [conn13796] command sledge.event_bases command: find
# 2017-08-09T20:11:40.573Z I COMMAND  [conn32266] command sledge.directory_user_matches command: distinct {
# 2017-08-09T20:11:22.933Z I COMMAND  [conn33473] command sledge.mcs_commands command: distinct {
# 2017-08-09T20:54:54.402Z I COMMAND  [conn52924] warning: log line attempted (20kB) over max size (10kB), printing beginning and end ... command sledge.directory_user_matches command: distinct { distinct: "directory_user_matches", key: "user_id", query: { $and: [ { user_id: { $ne: null

# =====================================================================
#  WORKING: deal with non WRITES first
# =====================================================================
cat  mongod.keysexamined.log | sed -E 's# warning: .* end \.\.\.##g' | sed -E 's#([0-9\-]+T[0-9:\.]+Z) [A-Z] ([A-Z]+)[ ]+.+\[(conn[0-9]+)\] ([a-zA-Z]+) ([^ ]+) ([a-zA-Z\.]+): ([a-zA-Z]+) .+keysExamined:([0-9]+) docsExamined:([0-9]+)#\1|\2|\3|\4|\5|\6|\7|\8|\9==#g' | sed -E 's#^(.*)== .+nreturned:([0-9]+) .* timeAcquiringMicros: \{ r: ([^,]+) \} \}, .+ ([0-9]+)ms#\1|\2|\3|\4#g' > temp.mkeq.log

# for logs that do not have timeAcquiringMicros
cat  temp.mkeq.log |  sed -E 's#([0-9\-]+T[0-9:\.]+Z) [A-Z] ([A-Z]+)[ ]+.+\[(conn[0-9]+)\] ([a-zA-Z]+) ([^ ]+) ([a-zA-Z\.]+): ([a-zA-Z]+) .+keysExamined:([0-9]+) docsExamined:([0-9]+)#\1|\2|\3|\4|\5|\6|\7|\8|\9==#g' | sed -E 's#^(.*)== .+nreturned:([0-9]+) .* ([0-9]+)ms#\1|\2|0|\3#g' > temp.mkea.log


# for logs that do not have nreturned
cat  temp.mkea.log |  sed -E 's#([0-9\-]+T[0-9:\.]+Z) [A-Z] ([A-Z]+)[ ]+.+\[(conn[0-9]+)\] ([a-zA-Z]+) ([^ ]+) ([a-zA-Z\.]+): ([a-zA-Z]+) .+keysExamined:([0-9]+) docsExamined:([0-9]+)#\1|\2|\3|\4|\5|\6|\7|\8|\9==#g' | sed -E 's#^(.*)== .* timeAcquiringMicros: \{ r: ([^,]+) \} \}, .+ ([0-9]+)ms#\1|\2|1|\3#g' > temp.mker.log

#  for logs that do not have nreturned and timeAcquiringMicros
cat  temp.mker.log |  sed -E 's#([0-9\-]+T[0-9:\.]+Z) [A-Z] ([A-Z]+)[ ]+.+\[(conn[0-9]+)\] ([a-zA-Z]+) ([^ ]+) ([a-zA-Z\.]+): ([a-zA-Z]+) .+keysExamined:([0-9]+) docsExamined:([0-9]+)#\1|\2|\3|\4|\5|\6|\7|\8|\9==#g' | sed -E 's#^(.*)== .* ([0-9]+)ms#\1|1|1|\2#g' > temp.mkera.log
# =====================================================================

# still fix WRITE


# clean up the WRITE logs 
cat  temp.mkeq.log | grep WRITE | head -1 | sed -E 's#([0-9\-]+T[0-9:\.]+Z) [A-Z] ([A-Z]+)[ ]+.+\[(conn[0-9]+)\] ([a-zA-Z]+) ([^ ]+) ([a-zA-Z]+): .+keysExamined:([0-9]+) docsExamined:([0-9]+)#\1|\2|\3|\4|\5|\6|\7|\8==#g' | sed -E 's#^(.*)== .+nreturned:([0-9]+) .* timeAcquiringMicros: \{ r: ([^,]+) \} \}, .+ ([0-9]+)ms#\1|\2|\3|\4#g' > temp.mkeq.log

cat  mongod.keysexamined.log |  sed -E 's#([0-9\-]+T[0-9:\.]+Z) [A-Z] ([A-Z]+)[ ]+.+\[(conn[0-9]+)\] ([a-zA-Z]+) ([^ ]+) ([a-zA-Z]+): ([a-zA-Z]+) .+keysExamined:([0-9]+) docsExamined:([0-9]+)#\1|\2|\3|\4|\5|\6|\7|\8|\9==#g' | sed -E 's#^(.*)== .+nreturned:([0-9]+) .* timeAcquiringMicros: \{ r: ([^,]+) \} \}, .+ ([0-9]+)ms#\1|\2|\3|\4#g' > temp.mkeq.log


cat  mongod.keysexamined.log |  grep WRITE 

# for logs that do not have timeAcquiringMicros
cat  temp.mkeq.log | sed -E 's#^(.*)== .*nreturned:([0-9]+) .+ ([0-9]+)ms#\1|\2|-1|\3#g' > temp.mkea.log
# for logs that do not have nreturned
cat temp.mkea.log | sed -E 's#^(.*)== .* timeAcquiringMicros: \{ r: ([^,]+) \} \}, .+ ([0-9]+)ms#\1|1|\2|\3#g' > temp.mker.log
#  for logs that do not have nreturned and timeAcquiringMicros
cat temp.mker.log | sed -E 's#^(.*)== .* ([0-9]+)ms#\1|1|-1|\2#g' > temp.mkera.log
echo "date|time|command|keysExamined|docsExamined|nreturned|timeAcquiringMicros|ms" > temp.mkoutput.log
cat temp.mkera.log | sed -E 's/^([0-9\-]+)T([0-9:\.]+)Z/\1|\2/g' >> temp.mkoutput.log
gsed 's/|/\t/g' temp.mkoutput.log > mongod.keysexamined.output.log
cat mongod.keysexamined.output.log | pbcopy
# date time command keysExamined docsExamined nreturned timeAcquiringMicros ms 
rm temp.mk*.log 

