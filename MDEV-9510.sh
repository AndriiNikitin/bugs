set -e

PRODUCT=${PRODUCT:-m}
ENVIRON=${ENVIRON:-10.1.20}

echo DOWNLOAD TEMPLATES

# just use current directory if called from framework
if [ ! -f common.sh ] ; then
  [ -d mariadb-environs ] || git clone http://github.com/AndriiNikitin/mariadb-environs
  cd mariadb-environs
  ./get_plugin.sh galera
fi

echo GENERATE SCRIPTS

rm -rf cluster1
_template/plant_cluster.sh cluster1
echo ${PRODUCT}1 > cluster1/nodes.lst
echo ${PRODUCT}2 >> cluster1/nodes.lst
echo ${PRODUCT}3 >> cluster1/nodes.lst

cluster1/replant.sh $ENVIRON

# create link to access nodes
ln -s $(pwd)/${PRODUCT}1* $(pwd)/cluster1/node1
ln -s $(pwd)/${PRODUCT}2* $(pwd)/cluster1/node2
ln -s $(pwd)/${PRODUCT}3* $(pwd)/cluster1/node3

echo DOWNLOAD PACKAGE IF NEEDED

./build_or_download.sh ${PRODUCT}1

echo GENERATE CONFIGURATION AND DATA DIRECTORY

cluster1/gen_cnf.sh innodb_buffer_pool_size=1G \
	log_bin \
	expire_logs_days=1 \
	max_binlog_size=4K \
	innodb_log_file_size=256M \
	innodb_flush_log_at_trx_commit=0 \
	innodb_lock_wait_timeout=10 \
	transaction-isolation=READ-COMMITTED \
       binlog_format=row \
       wsrep_log_conflicts=1 \
       wsrep_provider_options="cert.log_conflicts=1;gcache.size=1G" \
       innodb-strict-mode=1 \
       sync_binlog=1 \
	# skip-grant-tables

cluster1/install_db.sh
# cluster1/galera_setup_acl.sh || : # this needed for mysqldump

echo GENERATE INITIAL DATA 

cluster1/node1/startup.sh

for i in {1..5}; do
  cluster1/node1/sql.sh "set @N=0; create table t$i select @N:=@N+1  as a, @N as b from mysql.help_topic a, mysql.help_topic b limit 10000;"
  cluster1/node1/sql.sh "alter table t$i add primary key(a), add index(b)"
done

cluster1/node1/shutdown.sh

echo START CLUSTER

cluster1/galera_start_new.sh wsrep_sst_method=rsync

sleep 10
cluster1/galera_cluster_size.sh


# trap 'kill $(jobs -p)' EXIT
trap "exit" INT TERM
trap "kill 0" EXIT

sleep 10

echo START TEST

for I in {1..5}; do
  cluster1/sql_loop.sh "start transaction; update t$I set b=b+1 where a=$I; delete from t$I where a=2*$I; do sleep(10); commit" &

  cluster1/sql_loop.sh "start transaction; insert into t$I select floor(rand()*10000), floor(rand(10000)); do sleep(1); commit" &
  cluster1/sql_loop.sh "insert into t$I select floor(rand()*10000), floor(rand(10000));" &
  cluster1/sql_loop.sh "insert into t$I values(floor(rand()*10000), floor(rand(10000))) on duplicate key update b=rand()*10000;" &
  cluster1/sql_loop.sh "start transaction; insert into t$I select floor(rand()*10000), floor(rand(10000)); do sleep(1); rollback" &
  cluster1/sql_loop.sh "start transaction; insert into t$I select floor(rand()*10000), floor(rand(10000)); do sleep(2); commit" &

  cluster1/sql_loop.sh "start transaction; delete from t$I where b<1000; commit;" 30 &
  cluster1/sql_loop.sh "start transaction; delete from t$I where a<1000; do sleep(17); commit;" 5 &
  cluster1/sql_loop.sh "start transaction; delete from t$I where a<1000; do sleep(7); rollback;" &
  cluster1/sql_loop.sh "start transaction; delete from t$I where a>1000+rand()*9000; do sleep(7); rollback;" &

  cluster1/node1/sql_loop.sh "alter table t$I add column x int default 5" "$((10*$I))" &
  cluster1/node2/sql_loop.sh "alter table t$I drop column x" "$((10*$I))" &

  cluster1/node3/sql_loop.sh "create temporary table x select * from t$I; start transaction; delete from t$I where exists (select a from x where rand()>0.7 and x.a=t$I.a) limit 100; commit;" "$((10*$I))" &
  sleep $I
done

cluster1/sql_loop.sh "purge binary logs before now()" 61 &
cluster1/sql_loop.sh "flush privileges" &

while : ; do
  cluster1/node1/sql.sh show processlist  
  cluster1/node2/sql.sh show processlist  
  cluster1/node3/sql.sh show processlist  
echo ==== Appliers ====
  ( cluster1/node1/sql.sh show processlist 
  cluster1/node2/sql.sh show processlist
  cluster1/node3/sql.sh show processlist ) | grep 'system user' | grep -v 'wsrep aborter'
echo ==================
  sleep 10
done

