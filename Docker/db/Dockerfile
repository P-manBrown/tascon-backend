# syntax=docker/dockerfile:1
FROM mysql:9.0.1

ENV TZ=Asia/Tokyo

COPY <<-EOF /etc/mysql/conf.d/charset.cnf
	[mysqld]
	collation-server = utf8mb4_ja_0900_as_cs
EOF

COPY --chmod=755 ./initdb.d/. /docker-entrypoint-initdb.d/

USER mysql

EXPOSE 3306
