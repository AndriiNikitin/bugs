set -e

ver=system@debian~9.2

# just use current directory if called from framework
if [ ! -f common.sh ] ; then
  [ -d mariadb-environs ] || git clone http://github.com/AndriiNikitin/mariadb-environs
  cd mariadb-environs
  ./get_plugin.sh galera
fi

./get_plugin.sh galera
./get_plugin.sh docker
./get_plugin.sh xtrabackup

./replant.sh m5-$ver
m5*/image_create.sh
m5*/container_create.sh
m5*/exec-i.sh 'm0-system/install.sh 10.2'
m5*/exec-i.sh './replant.sh x0-system'
m5*/exec-i.sh 'x0-system/install.sh 2.4'




# ./get_plugin.sh hasky

