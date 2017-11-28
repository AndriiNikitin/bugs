set -e

ver=${1:-10.2~latest}

# just use current directory if called from framework
if [ ! -f common.sh ] ; then
  [ -d mariadb-environs ] || git clone http://github.com/AndriiNikitin/mariadb-environs
  cd mariadb-environs
  ./get_plugin.sh galera
fi

# ./get_plugin.sh hasky

function onExit {
  [ "$passed" == 1 ] && exit
  cluster1/tail_log.sh 100
# uncomment if you wish docker build hang on failire (to attach to container and troubleshoot)
#  sleep 10000
}
trap onExit EXIT

_template/plant_cluster.sh cluster1
echo m1 > cluster1/nodes.lst
echo m2 >> cluster1/nodes.lst
cluster1/replant.sh ${ver}

./build_or_download.sh m1

cluster1/gen_cnf.sh general_log=1
cluster1/install_db.sh
cluster1/configure_ssl.sh

# . cluster1/galera_setup_acl.sh
echo '[sst]' >> m1*/mysqldextra.cnf
echo 'encrypt=3' >> m1*/mysqldextra.cnf
echo "tcert=$(pwd)/$(ls -d m1*)/ssl/client-cert.pem" >> m1*/mysqldextra.cnf
echo "tkey=$(pwd)/$(ls -d m1*)/ssl/client-key.pem" >> m1*/mysqldextra.cnf
echo "tca=$(pwd)/$(ls -d _depot)/ssl/ca.pem" >> m1*/mysqldextra.cnf

echo '[sst]' >> m2*/mysqldextra.cnf
echo 'encrypt=3' >> m2*/mysqldextra.cnf
echo "tcert=$(pwd)/$(ls -d m2*)/ssl/client-cert.pem"  >> m2*/mysqldextra.cnf
echo "tkey=$(pwd)/$(ls -d m2*)/ssl/client-key.pem"  >> m2*/mysqldextra.cnf
echo "tca=$(pwd)/$(ls -d _depot)/ssl/ca.pem"  >> m2*/mysqldextra.cnf


cluster1/galera_start_new.sh wsrep_sst_method=xtrabackup-v2

sleep 45
cluster1/galera_cluster_size.sh
cluster1/sql.sh 'show variables like "wsrep_sst_method"'
grep -A10 -B10 -i "\[ERROR\]" m1*/dt/error.log || echo no errors found

cluster_size=$(m1*/sql.sh 'show status like "wsrep_cluster_size"')

[[ "${cluster_size}" =~ 2 ]] && passed=1
