
set -e

env1=m9-system@centos

# just use current directory if called from framework
if [ ! -f common.sh ] ; then
  [ -d mariadb-environs ] || git clone http://github.com/AndriiNikitin/mariadb-environs
  cd mariadb-environs
fi

./get_plugin.sh galera
./get_plugin.sh docker
./get_plugin.sh xtrabackup


./replant.sh $env1

$env1/image_create.sh
$env1/container_create.sh
$env1/exec-it.sh 'm0*/install.sh 10.2'
$env1/exec-i.sh './replant.sh x0-system'
$env1/exec-it.sh 'x0*/install.sh 2.4 || x0*/install.sh 2.4.8'
echo $($env1/container_commit.sh) > $env1/base_image_id

