env=${ENVIRON:-system2}
PARTITION_COUNT=${PARTITION_COUNT:-62}
ENGINE=${ENGINE:-InnoDB}
set -e

## Step 1. Setup default Environs cluster if needed
if [ ! -e common.sh ] ; then
  git clone http://github.com/AndriiNikitin/mariadb-environs
  cd mariadb-environs
fi
./get_plugin.sh spider

./replant.sh m1-$env
# ./build_or_download.sh m1

## Step 2. Setup Spider table referensing child tables on the same instance
[ ${ENGINE^^} != ROCKSDB ] || $EXTRA_OPT="plugin_load_add=ha_rocksdb $EXTRA_OPT"
m1*/gen_cnf.sh $EXTRA_OPT
m1*/install_db.sh
m1*/startup.sh
m1*/sql.sh source _plugin/spider/_script/install_spider.sql

tee ddl.sql <<"EOF"
CREATE TABLE `mytable` ( 
`id_mysql_replication_thread` int(11) NOT NULL,
`id_slave_name` int(11) NOT NULL,
`date` datetime NOT NULL,
`value` bigint(20) unsigned NOT NULL,
PRIMARY KEY `id_mysql_replication_thread_slave_int` (`id_mysql_replication_thread`,`id_slave_name`,`date`),
KEY `id_mysql_replication_thread_slave__int` (`id_mysql_replication_thread`,`id_slave_name`),
KEY `date_int_slave` (`date`,`id_mysql_replication_thread`,`id_slave_name`),
KEY `id_slave_name_slave_int` (`id_slave_name`) )
EOF

echo ENGINE="$ENGINE" >> ddl.sql
echo 'PARTITION BY LIST (`id_mysql_replication_thread`) (' >> ddl.sql

for (( c=1; c<$PARTITION_COUNT; c++ )) 
do
  echo "PARTITION pt$c VALUES IN ($c)," >> ddl.sql
done

echo "PARTITION pt$c VALUES IN ($c)" >> ddl.sql
echo " );" >> ddl.sql

m1*/spider_print_self_referencing_table.sh "$(cat ddl.sql)" > ddl_generated.sql
m1*/spider_populate_self_referencing_table.sh "$(cat ddl.sql)"

m1*/sql.sh 'select version()'
# m1*/sql.sh 'show create table mytable\G'
m1*/sql.sh 'insert into mytable select 1,1,now(),1'
m1*/sql.sh 'insert into mytable select 2,2,now(),1'
m1*/sql.sh 'select count(*) from mytable_1'
m1*/sql.sh 'select count(*) from mytable_2'
echo pass
