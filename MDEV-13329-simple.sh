
set -e
./get_plugin.sh galera

_template/plant_cluster.sh cluster1
echo m1 > cluster1/nodes.lst
echo m2 >> cluster1/nodes.lst
echo m3 >> cluster1/nodes.lst

# create all nodes as system2 framework and init datadir for each
cluster1/replant.sh system2
cluster1/gen_cnf.sh
cluster1/install_db.sh

# retry connecting and then remain idle 
( while : ; do mysql --defaults-file=$(pwd)/m2-system2/my.cnf -e 'show variables like "wsrep_on"; system sleep 10000;' 2>>log.log || : ; done ) &

trap "exit" INT TERM
trap "kill 0" EXIT

# cluster1/galera_setup_acl.sh
cluster1/galera_start_new.sh skip-grant-tables

cluster1/galera_cluster_size.sh

while : ; do
sleep 5
cluster1/sql.sh show status like '"wsrep%comment"'
done
