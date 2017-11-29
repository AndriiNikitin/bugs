set -e

env=m5-10.2@fedora~25

# just use current directory if called from framework
if [ ! -f common.sh ] ; then
  [ -d mariadb-environs ] || git clone http://github.com/AndriiNikitin/mariadb-environs
  cd mariadb-environs
fi

./get_plugin.sh docker

./replant.sh $env

$env/image_create.sh
$env/container_create.sh

$env/exec-i.sh './build_or_download.sh m0'
$env/exec-i.sh 'yum install -y perl-Time-HiRes perl-Memoize'
$env/exec-i.sh './m0*/bld/mysql-test/mtr --suite=rocksdb --par=4 --mem'
