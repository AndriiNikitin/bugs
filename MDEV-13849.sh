set -e

echo Setup default Environs cluster if needed
if [ ! -e common.sh ] ; then
  git clone http://github.com/AndriiNikitin/mariadb-environs
  cd mariadb-environs
fi
echo get plugins
./get_plugin.sh oracle-mysql
./get_plugin.sh spider

echo generate templates
./replant.sh m1-10.2.8
./replant.sh o1-5.7.19
./replant.sh o2-5.7.19
./replant.sh o3-5.7.19

_template/plant_cluster.sh myspider
echo m1 > myspider/nodes.lst
echo o1 >> myspider/nodes.lst
echo o2 >> myspider/nodes.lst
echo o3 >> myspider/nodes.lst

echo download and unpack tar packages
m1*/download.sh &
o1*/download.sh &
wait

echo generate my.cnf and install datadirs
myspider/gen_cnf.sh innodb_flush_log_at_trx_commit=0
myspider/install_db.sh
echo start up servers
myspider/startup.sh

echo initialize root node
m1*/sql.sh source _plugin/spider/_script/install_spider.sql

tee ddl.sql <<'EOF'
CREATE TABLE `history` (
`itemid` bigint(20) unsigned NOT NULL,
`clock` int(11) NOT NULL DEFAULT 0,
`value` double(16,4) NOT NULL DEFAULT 0.0000,
`ns` int(11) NOT NULL DEFAULT 0,
KEY `history_1` (`itemid`,`clock`)
) ENGINE=InnoDB
PARTITION BY HASH (itemid + clock)
(
PARTITION pt1,
PARTITION pt2,
PARTITION pt3
);
EOF

echo create tables
myspider/spider_create_table_filter_execute.sh "$(cat ddl.sql)"

echo check tables are here on each node
myspider/sql.sh 'select count(*) from history'

echo populate 100000 rows through root node
for i in {1..100000} ; do
  m1*/sql.sh insert into history select $i, $i, $i, $i
done

echo check rows on each node
myspider/sql.sh 'select count(*) from history'
myspider/sql.sh 'select version()'
