#!/bin/bash
set -eu

# Grant on a pattern so that the test databases suffixed with TEST_ENV_NUMBER
# are covered too, escaping "_" because it is a wildcard in the pattern.
test_db_pattern="${MYSQL_TEST_DATABASE//_/\\_}%"

mysql=(mysql -uroot -p"${MYSQL_ROOT_PASSWORD}")
"${mysql[@]}" <<-EOSQL
	CREATE DATABASE IF NOT EXISTS ${MYSQL_TEST_DATABASE};
	GRANT ALL ON \`${test_db_pattern}\`.* TO '${MYSQL_USER}'@'%';
EOSQL
