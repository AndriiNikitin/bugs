#############
## Script will setup local cluster from installed MariaDB binaries
## first node will use default MariaDB config
## the rest nodes will have config file in m*-sysem2/my.cnf 
## and datadir in in m*-system2/dt

# just use current directory if called from framework
if [ ! -f common.sh ] ; then
  [ -d mariadb-environs ] || git clone http://github.com/AndriiNikitin/mariadb-environs
  cd mariadb-environs
fi

./get_plugin.sh galera

which mysqld_safe > /dev/null || { (>&2 echo cannot find mysqld); exit 2; }
sudo mysqladmin status 2>/dev/null && { (>&2 echo it looks server is already started); exit 2; }

set -e

_template/plant_cluster.sh cluster1
echo m1 > cluster1/nodes.lst
echo m2 >> cluster1/nodes.lst

# create all nodes as system2 framework and init datadir for each
cluster1/replant.sh system2
cluster1/gen_cnf.sh $MYSQLD_EXTA_OPT # e.g. general_log=1
cluster1/install_db.sh $MYSQLD_EXTA_OPT

# replace first node with scripts for installed binaries
./replant.sh m0-system

echo "m0
$(cat cluster1/nodes.lst)" > cluster1/nodes.lst

cluster1/galera_setup_acl.sh

# inject mysqldextra.cnf into system config
if [ -e /etc/my.cnf ] ; then
  grep -q mysqldextra.cnf /etc/my.cnf || echo !include $(pwd)/m0-system/mysqldextra.cnf  | sudo tee -a /etc/my.cnf
elif [ -e /etc/mysql/my.cnf ] ; then
  grep -q mysqldextra.cnf /etc/mysql/my.cnf || echo !include $(pwd)/m0-system/mysqldextra.cnf  | sudo tee -a /etc/mysql/my.cnf
fi

cluster1/galera_start_new.sh
# let it settle
sleep 5
cluster1/galera_cluster_size.sh

sz="$(m0*/sql.sh 'show status like "wsrep_cluster_size"')"

[ 'wsrep_cluster_size	3' == "$sz" ] || { (>&2 echo Cluster didnt start); exit 1; }

