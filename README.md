logs_ddl
========

PostgreSQL extension to log all DDL changes into separate table.

Install
-------
```sh
sudo make install
```

Install in PostgreSQL
---------------------
```sql
CREATE EXTENSION logs_ddl;
```

Development
-----------
- Build and launch container
```sh
# build
docker-compose build

# launch (as daemon)
docker-compose up -d
docker logs -f postgres_test
#   OR
# launch and watch logs
docker-compose up
```
- Connect to container and test
```sh
docker exec -it postgres_test psql -U testuser -d testdb
# in psql:
CREATE EXTENSION logs_ddl;
```
- Clean
```sh
docker-compose down
```


TODO:
- do not remove logs table when drop