
set -e

base_image=$(cat m9*/base_image_id)

node1=m2-system@centos~7
node2=m3-system@centos~7

./replant.sh $node1
./replant.sh $node2

$node1/container_cleanup.sh
$node2/container_cleanup.sh

$node1/container_create.sh $base_image
$node2/container_create.sh $base_image

# patch MDEV-14256
for node in $node1 $node2 ; do
# uncomment for verbose sst in error log
#  $node/exec-i.sh 'echo '\''set -x'\'' >> $(dirname $(which wsrep_sst_xtrabackup-v2))/wsrep_sst_common'

# uncomment to MDEV-14256
  $node/exec-i.sh 'sed -i -e '"'"'s/if \[ -n "\${WSREP_SST_OPT_ADDR_PORT:-}" \]; then/if \[ -n "\${WSREP_SST_OPT_ADDR:-}" \]; then/g'"'"' $(dirname $(which wsrep_sst_xtrabackup-v2))/wsrep_sst_common'
  $node/exec-i.sh 'sed -i -e '"'"'s/if \[ "\$WSREP_SST_OPT_PORT" != "\$WSREP_SST_OPT_ADDR_PORT" \]; then/if \[ -n "\$WSREP_SST_OPT_ADDR_PORT" -a "\$WSREP_SST_OPT_PORT" != "\$WSREP_SST_OPT_ADDR_PORT" \]; then/g'"'"' $(dirname $(which wsrep_sst_xtrabackup-v2))/wsrep_sst_common'

  :
done

# must indicate that installed service must use environs configuration
$node1/exec-i.sh 'cp /etc/my.cnf /etc/my.~cnf.docker && echo "!include /farm/m0-system/mysqldextra.cnf" > /etc/my.cnf' || \
  $node1/exec-i.sh 'cp /etc/mysql/my.cnf /etc/mysql.my.~cnf.docker && echo "!include /farm/m0-system/mysqldextra.cnf" > /etc/mysql/my.cnf'

$node2/exec-i.sh 'cp /etc/my.cnf /etc/my.~cnf.docker && echo "!include /farm/m0-system/mysqldextra.cnf" > /etc/my.cnf' || \
  $node2/exec-i.sh 'cp /etc/mysql/my.cnf /etc/mysql.my.~cnf.docker && echo "!include /farm/m0-system/mysqldextra.cnf" > /etc/mysql/my.cnf'

# renew scripts just in case if templates were updated recently
$node1/exec-i.sh './replant.sh m0*'
$node2/exec-i.sh './replant.sh m0*'

# workaround as framework expect test database should exist
$node1/exec-i.sh 'mkdir -p /var/lib/mysql/test'

$node1/galera_start_new.sh skip-grant-tables wsrep_sst_method=xtrabackup-v2 &
sleep 6
$node2/galera_join.sh $node1 skip-grant-tables wsrep_sst_method=xtrabackup-v2 &
sleep 2
$node2/exec-it.sh 'tail -f /var/lib/mysql/*.err | grep -i -B2 -E "err|warn|started|fail" '
