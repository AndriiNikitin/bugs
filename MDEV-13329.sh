set -e
env=system2
if [ ! -f common.sh ] ; then
  [ -d mariadb-environs ] || git clone http://github.com/AndriiNikitin/mariadb-environs
  cd mariadb-environs
fi

[ ! -z  "$(which mysqladmin 2>/dev/null )" ] || export PATH=$PATH:/usr/local/mysql/bin
[ ! -z  "$(which mysqladmin 2>/dev/null )" ] || { echo 'cannot find mysqladmin' ; exit 1 ;  }

./get_plugin.sh maxscale
./get_plugin.sh galera

_template/plant_cluster.sh c1
echo m7 > c1/nodes.lst
echo m8 >> c1/nodes.lst
# echo m9 >> c1/nodes.lst

echo GENERATE TEMPLATES
c1/replant.sh $env
./replant.sh s1-2.1.10

echo "DOWNLOAD PACKAGES (if needed)"
./build_or_download.sh s1

echo GENERATE CONFIG FILES
c1/gen_cnf.sh general_log=1
echo INITIALIZE DATADIRs
c1/install_db.sh
echo STARTUP SERVERS TO SETUP ACL
c1/startup.sh
c1/galera_setup_acl.sh
c1/maxscale_setup_acl.sh
c1/shutdown.sh

echo STARTUP Galera and MaxScale
s1*/gen_galera_cnf.sh c1
c1/galera_start_new.sh
s1*/startup.sh

# echo BRIEFLY SLEEP TO LET MaxScale CONNECT TO THE SERVERS
# sleep 5
# echo SHUTDOWN SERVERS
# c1/shutdown.sh

# echo STARTUP Galera
# c1/galera_start_new.sh

sleep 5

echo CREATING TABLE in MAXSCALE
s1*/mysql.sh create table t1 select 5

echo MONITOR Nodes\' OUTPUT
while :; do
  sleep 1
# confirm it is on each node in cluster
  c1/mysql.sh 'select * from t1'

  c1/galera_cluster_size.sh
done
