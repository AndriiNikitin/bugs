set -e

# this script will crash your OS, 
# so it may damage your data or system permanently
# comment out line below if you understand the risk
exit 1

echo !! sudo will be used to CRASH OS when background jobs are started !!
echo 1 | sudo tee /proc/sys/kernel/sysrq
# above command is needed to crash OS later 
# with following command:
# echo c | sudo /proc/sysrq-trigger

ulimit -n 4000 || { echo "error: could not increase open files limit ($?)" ; exit 1; }

# env1 is main testing instance - it should have full ACID settings
# env2 is used to load binary log from env1 - we use non-durable settings to speedup load

env1=${ENVIRON1:-m7-system2}
env2=${ENVIRON2:-m8-system2}
ENGINE=${ENGINE:-RocksDB}
EXTRA_OPT=${EXTRA_OPT}
logfile=MDEV-14103.log

echo =========================================== >> "$logfile"
echo =========================================== >> "$logfile"
echo "$ENGINE" "$EXTRA_OPT" >> "$logfile"
echo =========================================== >> "$logfile"

set -u

# this function is needed to work around MDEV-14131:
# Lost connection to MySQL server at 'handshake: reading inital communication packet', system error: 22

# Retries a command on failure.
# $1 - the max number of attempts
# $2... - the command to run
function retry() {
    local -r -i max_attempts="$1"; shift
    local -r cmd="$@"
    local -i attempt_num=1

    until $cmd
    do
        if (( attempt_num == max_attempts ))
        then
            echo "Attempt $attempt_num failed and there are no more attempts left!"
            return 1
        else
            echo "Attempt $attempt_num failed! Trying again in $attempt_num seconds..."
            sleep $(( attempt_num++ ))
        fi
    done
}


if [ ! -e common.sh ] ; then
  git clone http://github.com/AndriiNikitin/mariadb-environs
  cd mariadb-environs
fi

./replant.sh $env1
./replant.sh $env2

./build_or_download.sh $env1
./build_or_download.sh $env1

trap "exit" INT TERM
trap "read -n1 -r -p 'Press any key to continue...' key ; kill 0" EXIT

if [ ${ENGINE^^} == ROCKSDB ] ; then
  if ls $env1/configure_rocksdb_plugin.sh 2>/dev/null ; then
    EXTRA_OPT="configure_rocksdb_plugin=1 $EXTRA_OPT"
  else
    EXTRA_OPT="plugin_load_add=ha_rocksdb $EXTRA_OPT"
  fi
fi

[[ $EXTRA_OPT =~ max_connections ]] || EXTRA_OPT="max_connections=4000 $EXTRA_OPT"

$env1/gen_cnf.sh $EXTRA_OPT
$env1/install_db.sh
# add extra option to speedup binlog load
$env2/gen_cnf.sh $EXTRA_OPT loose-rocksdb-flush-log-at-trx-commit=2 loose-innodb-flush-log-at-trx-commit=2
$env2/install_db.sh

# testing group commit
$env1/gen_cnf.sh log_bin=blog binlog_format=row $EXTRA_OPT

# sometimes system files from env2 are not here after OS crash,
# try to wokraround it with sync command:
sync

$env1/startup.sh

sleep 1

# we try to generate load with following rules:
# in each database:
# (number of rows in tables a and b is equal 
# OR
# difference of number of rows in tables a and b is multiple
# exact number in database name e.g. d20) 
# AND
# for each row in a and b
# ( col1 < col2 < col3
# OR
# col1 = col2 < col3 )
# if such conditions are not honoured after crash 
# - then we consider that system doesn't meet ACID requirements
for i in {1..40} ; do
  $env1/sql.sh "create database d$i"
  $env1/sql.sh "create table d$i.a (a int, b int, c varbinary(40), primary key(a,b,c) ) engine=$ENGINE"
  $env1/sql.sh "create table d$i.b (a int, b int, c varbinary(40), primary key(a,b) ) engine=$ENGINE"
done

$env1/sql.sh 'delimiter ;;
create procedure test.cr(a int, b int, offst int) if ( a = b ) || ( a = b+offst ) then commit; else rollback; end if;;'


# insert loops
for i in {1..40} ; do
  $env1/sql_loop.sh "use d$i; begin; set @N=floor(rand()*100000)+1; insert into d$i.a select @N,@N,@N-1; insert into d$i.b select @N,@N,@N-1; commit" &
  $env1/sql_loop.sh "use d$i; begin; set @N=floor(rand()*100000)+1; insert into d$i.a select @N,@N,@N-1; insert into d$i.b select @N,@N,@N-1; commit" &
  $env1/sql_loop.sh "use d$i; begin; set @N=floor(rand()*100000)+1; insert into d$i.a select @N,@N,@N-1; insert into d$i.b select @N,@N,@N-1; commit" &
  $env1/sql_loop.sh "use d$i; begin; set @N=floor(rand()*100000)+1; insert into d$i.a select @N,@N,@N-1; insert into d$i.b select @N,@N,@N-1; commit" &
  $env1/sql_loop.sh "use d$i; begin; set @N=floor(rand()*100000)+1; insert into d$i.b select @N,@N,@N-1; insert into d$i.a select @N,@N,@N-1; commit" &

  $env1/sql_loop.sh "use d$i; begin; set @N=floor(rand()*100000)+1; set @M=floor(rand()*10000); insert into d$i.a select @N,@N+@M,@N+@M+1; insert into d$i.b select @N,@N+@M,@N+@M+1; commit" &
  $env1/sql_loop.sh "use d$i; begin; set @N=floor(rand()*100000)+1; set @M=floor(rand()*10000); insert into d$i.b select @N,@N+@M,@N+@M+1; insert into d$i.a select @N,@N+@M,@N+@M+1; commit" &
done

for i in {1..40} ; do
  $env1/sql_loop.sh "use d$i; begin; set @N=floor(rand()*1000)+1; insert into d$i.a select @N,@N,@N-1; insert into d$i.b select @N,@N,@N-1; commit" 1 &
  $env1/sql_loop.sh "use d$i; begin; set @N=floor(rand()*1000)+1; insert into d$i.a select @N,@N,@N-1; do sleep(1); insert into d$i.b select @N,@N,@N-1; do sleep(1); rollback" 1 &
  $env1/sql_loop.sh "use d$i; begin; set @N=floor(rand()*100000)+1; set @M=floor(rand()*10000); insert into d$i.a select @N,@N+@M,@N+@M+1; insert into d$i.b select @N,@N+@M,@N+@M+1; commit" 1 &
done

# delete loops
for i in {1..40} ; do
  N=$(( RANDOM ))
  r=$(( ( RANDOM % 100 )  + 1 )) 
  r1=$(( $r + $i ))
  $env1/sql_loop.sh "use d$i; begin; delete from a where a < $N and limit $r; set @rc=row_count(); delete from b limit $r1; call test.cr(row_count(), @rc, $i);" 5 &
  $env1/sql_loop.sh "use d$i; begin; delete from a where a < $N and limit $r; set @rc=row_count(); delete from b limit $r1; call test.cr(row_count(), @rc, $i);" 4 &
  $env1/sql_loop.sh "use d$i; begin; delete from a where a = floor(rand()*100000) limit 1; set @rc=row_count(); delete from b where a=floor(rand()*10000) limit 1; call test.cr(row_count(),@rc,$i);" &
  $env1/sql_loop.sh "use d$i; begin; delete from a where a = floor(rand()*100000) limit 2; set @rc=row_count(); delete from b where a=floor(rand()*10000) limit 2; call test.cr(row_count(),@rc,$i);" 1 &
  $env1/sql_loop.sh "use d$i; begin; delete from a where a = floor(rand()*100000) limit 4; set @rc=row_count(); delete from b where a=floor(rand()*10000) limit 4; call test.cr(row_count(),@rc,$i);" 1 &
  $env1/sql_loop.sh "use d$i; begin; delete from a where a = floor(rand()*100000) limit 5; set @rc=row_count(); delete from b where a=floor(rand()*10000) limit 5; call test.cr(row_count(),@rc,$i);" 4 &
  
  $env1/sql_loop.sh "use d$i; begin; delete from a where a = floor(rand()*100000) limit 10; do sleep(1); delete from b where a=floor(rand()*10000) limit 10; do sleep(1); rollback;" 1 &
done

# update loops
for i in {1..40} ; do
  N=$(( RANDOM ))
  r=$(( ( RANDOM % 100 )  + 1 )) 
  r1=$(( $r + $i ))
  $env1/sql_loop.sh "use d$i; begin; update a set b=a, c=0 where a = floor(rand()*100000) limit 1; commit;" 1 &
  $env1/sql_loop.sh "use d$i; begin; update b set b=a, c=0 where a = floor(rand()*100000) limit 1; commit;" 1 &
  $env1/sql_loop.sh "use d$i; begin; update a set b=a+a, c=b+a where a = floor(rand()*100000) limit 1; commit;" 1 &
  $env1/sql_loop.sh "use d$i; begin; update b set b=a+a, c=b+a where a = floor(rand()*100000) limit 1; commit;" 1 &
  $env1/sql_loop.sh "use d$i; begin; update b set b=a+a, c=b+a where a = floor(rand()*100000) limit 1; update a set b=a, c=b-a where a = floor(rand()*100000) limit 1; commit;" 1 &
  $env1/sql_loop.sh "use d$i; begin; update b set b=0, c=floor(rand()*10000) where a = floor(rand()*100000) limit 10; rollback;" 1 &
  $env1/sql_loop.sh "use d$i; begin; update a set b=floor(rand()*100000), c=floor(rand()*100000) where a = floor(rand()*100000) limit 10; rollback;" 1 &
done

# todo - kill loop

# this is for very extreme cases like sync-binlog=0
sync

echo let load run for some time...
i=3
while [ $i -gt 1 ] ; do
i=$(( i-1 ))
# $env1/sql.sh 'show processlist; show global status like "Com_insert%"; show global status like "Handler_commit"'
retry 3 $env1/sql.sh 'show global status like "Handler_commit"'
sleep 5
retry 3 $env1/status.sh
done


read -n1 -r -p 'Background jobs are started. Press any key to crash OS...' key
# insert magic row
retry 3 $env1/sql.sh insert into d1.b select 1000000,1,1
echo c | sudo tee /proc/sysrq-trigger
