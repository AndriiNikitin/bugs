if [ ! -e common.sh ] ; then
  git clone http://github.com/AndriiNikitin/mariadb-environs
  cd mariadb-environs
fi

./get_plugin.sh oracle-mysql

set -e
env=${ENV:-m1-10.2.11}

./replant.sh $env
./build_or_download.sh $env

$env/gen_cnf.sh max_heap_table_size=5000000000

$env/install_db.sh

$env/startup.sh


$env/sql.sh 'select version()'

trap "exit" INT TERM
trap "kill 0" EXIT

# create big table
$env/sql.sh 'create table base(f bigint unsigned, f1 int, f2 int, f3 int, f4 int, f5 int, f6 int, f7 int, f8 int, f9 int, f10 int, f11 int, f12 int, f13 int, f14 int, f15 int, key(f), key(f1), key(f2), key(f3), key(f4), key(f5), key(f6), key(f7), key(f8), key(f9), key(f10), key(f11), key(f12), key(f13), key(f14), key(f15)) engine=Memory;'
$env/sql.sh 'set @N=0; 
insert into base select @N:=@N+1, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N;
insert into base select @N:=@N+1, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N from base b1, base b2, base b3;
insert into base select @N:=@N+1, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N from base b1, base b2, base b3;
insert into base select @N:=@N+1, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N from base b1, base b2, base b3;
insert into base select @N:=@N+1, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N, @N from base b1, base b2 limit 1000000;
'
$env/sql.sh 'select count(*) from base'


for i in {0..5} ; do
  ( 
    for j in {0..99} ; do
      $env/sql.sh "create table pre$(( 100 * i + j )) like base; insert into pre$(( 100 * i + j )) select * from base limit 100000;"
    done 
  ) &
done

wait

for i in {1..40} ; do
  $env/sql_loop.sh "create table t$i like base; insert into t$i select * from base limit 1000000; drop table t$i; 
create table t$i like base; insert into t$i select * from base limit 1000000; drop table t$i;
create table t$i like base; insert into t$i select * from base limit 1000000; drop table t$i;" &
done

while : ; do
# $env/sql.sh 'show global status like "Handler_commit"' || :
# $env/sql.sh 'show processlist' || :
# $env/sql.sh 'show table status' || :

$env/sql.sh 'select concat("Total size of HEAP tables: ", floor(sum(data_length + index_length)/1024/1024), " Mb") as size_of_all_tables from information_schema.tables where engine="MEMORY"' || :
# free -m
top -cbn1 | grep [m]ysqld
sleep 10
done

