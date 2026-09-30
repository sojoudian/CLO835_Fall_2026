FROM mysql:8.0

COPY ./mysql.sql /tmp

CMD [ "mysqld", "--init-file=/tmp/mysql.sql" ]