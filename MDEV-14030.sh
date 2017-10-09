set -e

PRODUCT=${PRODUCT:-m}
ENVIRON=${ENVIRON:-10.1~latest}

echo DOWNLOAD TEMPLATES

# just use current directory if called from framework
if [ ! -f common.sh ] ; then
  [ -d mariadb-environs ] || git clone http://github.com/AndriiNikitin/mariadb-environs
  cd mariadb-environs
  ./get_plugin.sh galera
  ./get_plugin.sh hasky
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

cluster1/gen_cnf.sh 
cluster1/install_db.sh
cluster1/galera_setup_acl.sh || : # this needed for wsrep_sst_mysqldump

echo GENERATE INITIAL DATA 

cluster1/node1/startup.sh

for i in {1..5}; do
  cluster1/node1/sql.sh "set @N=0; create table t$i select @N:=@N+1  as a, @N as b from mysql.help_topic a, mysql.help_topic b limit 10000;"
  cluster1/node1/sql.sh "alter table t$i add primary key(a), add index(b)"
done

cluster1/node1/sql.sh 'set @N=0; create table a engine=myisam select @N:=@N+1  as a, @N as b from mysql.help_topic a, mysql.help_topic b limit 10000;'
cluster1/node1/sql.sh 'set @N=0; create table b engine=aria select @N:=@N+1  as a, @N as b from mysql.help_topic a, mysql.help_topic b limit 10000;'

cluster1/node1/shutdown.sh

echo START CLUSTER

cluster1/galera_start_new.sh wsrep_sst_method=xtrabackup-v2

sleep 10
cluster1/galera_cluster_size.sh

cluster1/sql.sh 'select count(*) from t1; select count(*) from t2; select count(*) from t3; select count(*) from t4; select count(*) from t5; select count(*) from a;'

