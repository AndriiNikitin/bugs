ver1=${1:-"10.1.28"}
set -e

# just use current directory if called from framework
if [ ! -f common.sh ] ; then
  [ -d mariadb-environs ] || git clone http://github.com/AndriiNikitin/mariadb-environs
  cd mariadb-environs
fi
./get_plugin.sh galera

./replant.sh m1-$ver1
m1*/download.sh

m1*/gen_cnf.sh $MYSQLD_EXTRA_OPT
m1*/install_db.sh
if m1*/galera_start_new.sh $WSREP_EXTRA_OPT ; then
  m1*/status.sh
else
  echo '***'
  echo 'Failed to connect, below are resent messages from log:'
  echo '***'
  tail m1*/dt/error.log
  exit 1
fi
