FROM postgres:14-alpine

ADD ./pgconfig/demo/*.sql /docker-entrypoint-initdb.d/demo/
ADD ./pgconfig/init.sql /docker-entrypoint-initdb.d/*.sql
