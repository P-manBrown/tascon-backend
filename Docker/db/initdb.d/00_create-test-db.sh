#!/bin/bash
set -eu

mysql=(mysql -uroot -p"${MYSQL_ROOT_PASSWORD}")
"${mysql[@]}" <<-EOSQL
	CREATE DATABASE IF NOT EXISTS ${MYSQL_TEST_DATABASE};
	GRANT ALL ON ${MYSQL_TEST_DATABASE}.* TO '${MYSQL_USER}'@'%';
EOSQL
