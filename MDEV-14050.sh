if [ ! -e common.sh ] ; then
  git clone http://github.com/AndriiNikitin/mariadb-environs
  cd mariadb-environs
fi

set -e
ulimit -n 12000
v=10.2.11

./replant.sh m1-$v
./build_or_download.sh m1

m1*/gen_cnf.sh max_heap_table_size=5000000000 max_connections=650 table_open_cache=4000

m1*/install_db.sh

( m1*/startup.sh )

trap "exit" INT TERM
trap "kill 0" EXIT

for i in {1..600} ; do
  m1*/sql.sh "create table pre$i (f bigint unsigned, f1 int, f2 int, f3 int, f4 int, f5 int, f6 int, f7 int, f8 int, f9 int, f10 int, f11 int, f12 int, f13 int, f14 int, f15 int, key(f), key(f1), key(f2), key(f3), key(f4), key(f5), key(f6), key(f7), key(f8), key(f9), key(f10), key(f11), key(f12), key(f13), key(f14), key(f15)) engine=Memory; insert into pre$i select seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq from seq_1_to_100000;" &
done

wait

for i in {1..40} ; do
  m1*/sql_loop.sh "create table t$i (f bigint unsigned, f1 int, f2 int, f3 int, f4 int, f5 int, f6 int, f7 int, f8 int, f9 int, f10 int, f11 int, f12 int, f13 int, f14 int, f15 int, key(f), key(f1), key(f2), key(f3), key(f4), key(f5), key(f6), key(f7), key(f8), key(f9), key(f10), key(f11), key(f12), key(f13), key(f14), key(f15)) engine=Memory; insert into t$i select seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq from seq_1_to_1000000; drop table t$i; create table t$i (f bigint unsigned, f1 int, f2 int, f3 int, f4 int, f5 int, f6 int, f7 int, f8 int, f9 int, f10 int, f11 int, f12 int, f13 int, f14 int, f15 int, key(f), key(f1), key(f2), key(f3), key(f4), key(f5), key(f6), key(f7), key(f8), key(f9), key(f10), key(f11), key(f12), key(f13), key(f14), key(f15)) engine=Memory; insert into t$i select seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq from seq_1_to_1000000; drop table t$i; create table t$i (f bigint unsigned, f1 int, f2 int, f3 int, f4 int, f5 int, f6 int, f7 int, f8 int, f9 int, f10 int, f11 int, f12 int, f13 int, f14 int, f15 int, key(f), key(f1), key(f2), key(f3), key(f4), key(f5), key(f6), key(f7), key(f8), key(f9), key(f10), key(f11), key(f12), key(f13), key(f14), key(f15)) engine=Memory; insert into t$i select seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq from seq_1_to_1000000; drop table t$i; create table t$i (f bigint unsigned, f1 int, f2 int, f3 int, f4 int, f5 int, f6 int, f7 int, f8 int, f9 int, f10 int, f11 int, f12 int, f13 int, f14 int, f15 int, key(f), key(f1), key(f2), key(f3), key(f4), key(f5), key(f6), key(f7), key(f8), key(f9), key(f10), key(f11), key(f12), key(f13), key(f14), key(f15)) engine=Memory; insert into t$i select seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq from seq_1_to_1000000; drop table t$i; create table t$i (f bigint unsigned, f1 int, f2 int, f3 int, f4 int, f5 int, f6 int, f7 int, f8 int, f9 int, f10 int, f11 int, f12 int, f13 int, f14 int, f15 int, key(f), key(f1), key(f2), key(f3), key(f4), key(f5), key(f6), key(f7), key(f8), key(f9), key(f10), key(f11), key(f12), key(f13), key(f14), key(f15)) engine=Memory; insert into t$i select seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq from seq_1_to_1000000; drop table t$i; create table t$i (f bigint unsigned, f1 int, f2 int, f3 int, f4 int, f5 int, f6 int, f7 int, f8 int, f9 int, f10 int, f11 int, f12 int, f13 int, f14 int, f15 int, key(f), key(f1), key(f2), key(f3), key(f4), key(f5), key(f6), key(f7), key(f8), key(f9), key(f10), key(f11), key(f12), key(f13), key(f14), key(f15)) engine=Memory; insert into t$i select seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq from seq_1_to_1000000; drop table t$i; create table t$i (f bigint unsigned, f1 int, f2 int, f3 int, f4 int, f5 int, f6 int, f7 int, f8 int, f9 int, f10 int, f11 int, f12 int, f13 int, f14 int, f15 int, key(f), key(f1), key(f2), key(f3), key(f4), key(f5), key(f6), key(f7), key(f8), key(f9), key(f10), key(f11), key(f12), key(f13), key(f14), key(f15)) engine=Memory; insert into t$i select seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq, seq from seq_1_to_1000000; drop table t$i;" &
done

while : ; do
# m1*/sql.sh 'show global status like "Handler_commit"' || :
# m1*/sql.sh 'show processlist' || :
# m1*/sql.sh 'show table status' || :

m1*/sql.sh 'select sum(data_length + index_length)/1024/1024 as size_of_all_tables from information_schema.tables' || :
# free -m
top -cbn1 | grep [m]ysqld
sleep 10
done

