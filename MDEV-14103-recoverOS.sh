set -e

env1=${ENVIRON1:-m7-system2}
env2=${ENVIRON2:-m8-system2}
logfile=MDEV-14103.log

$env2/startup.sh
echo restore data from binary log in background
mysqlbinlog $env1/dt/blog*.000* | mysql --defaults-file=$(pwd)/$env2/my.cnf &
job=$!

trap "exit" INT TERM
trap 'res=$?; [ -z "$job" ] || kill $job; ( exit $res )' EXIT

$env1/startup.sh

# echo check consistency
for i in {1..40} ; do
  arowcount=$($env1/sql.sh "select count(*) from d$i.a") || :
  browcount=$($env1/sql.sh "select count(*) from d$i.b") || :
  (( (browcount - arowcount) % i == 0 )) || echo unexpected number of rows in d$i : $arowcount vs $browcount | tee -a $logfile
done

echo consistency checks completed | tee -a $logfile

echo "waiting binlog import to finish (process: $job)"
wait $job
job=""

echo compare data

for i in {1..40} ; do
# first compare row count
  res1="$($env1/sql.sh 'use d'$i'; select count(*) from a union all select count(*) from b')" ||:
  res2="$($env2/sql.sh 'use d'$i'; select count(*) from a union all select count(*) from b')" ||:
  if [ "$res1" != "$res2" ] ; then
    echo "row count is different in d$i : ("$res1") vs ("$res2")" | tee -a $logfile
  else
    res1="$($env1/sql.sh checksum table d$i.a, d$i.b)"
    res2="$($env2/sql.sh checksum table d$i.a, d$i.b)"
    [ "$res1" == "$res2" ] || echo "checksum verification failed: ("$res1") vs ("$res2")" | tee -a $logfile
  fi
done

echo checking magic row...
[ 1 == "$($env2/sql.sh select 1 from d1.b where a=1000000 and b=1 and c=1)" ] || echo magic row not found | tee -a $logfile

echo done | tee -a $logfile
