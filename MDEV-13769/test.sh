mysqld_safe &
sleep 10
set -e
mysql -e 'INSTALL SONAME "auth_pam"'
mysql -e 'CREATE USER a@localhost IDENTIFIED VIA pam USING "mtest"'

mysql -N -e'select now()' -ua -p1
mysql -N -e'select now()' -ua -p2 || echo '^ Successfully denied wrong password'
mysql -N -e'select now()' -ua -p1 && echo '^ Correct password still works'

mysql -N -e'select now()' -ua -p2 || \
	  mysql -N -e'select now()' -ua -p2 || \
	    mysql -N -e'select now()' -ua -p2 || \
	      echo '^ Successfully denied wrong password 3 times'

mysql -N -e'select now()' -ua -p1 || echo '^ Now correct password is denied as well'
sleep 61
mysql -N -e'select now()' -ua -p1 && echo '^ Accound is unlocked again'

