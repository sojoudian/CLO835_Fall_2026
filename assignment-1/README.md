# CLO835 Assignment 1 — two-tier web application

A Flask web tier and a MySQL data tier, each in its own container, on a custom
Docker bridge network.

## Run it locally, without Docker

Ubuntu 24.04 and later protect the system Python (PEP 668), so `pip3 install`
into the system fails. Use a virtual environment.

```bash
sudo apt-get update -y
sudo apt-get install -y python3-venv mysql-client

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 app.py
```

## Build the images

```bash
# the data tier
docker build -t my_db -f Dockerfile_mysql .

# the web tier
docker build -t my_app -f Dockerfile .
```

## Run the two tiers on a custom bridge network

Containers on a user-defined network resolve each other **by container name**.
The default bridge does not do that.

```bash
docker network create --driver bridge clo835-a1

docker run -d --name mysql-db --network clo835-a1 \
  -e MYSQL_ROOT_PASSWORD=pw my_db

docker run -d --name blue --network clo835-a1 -p 8081:8080 \
  -e DBHOST=mysql-db -e DBPORT=3306 -e DBUSER=root -e DBPWD=pw \
  -e DATABASE=employees -e APP_COLOR=blue my_app
```

`DBHOST` is the container name `mysql-db`. No IP address is needed, and
`docker inspect` is not needed.

## The three colours

Run the same image three times, on three host ports, with three colours.

```bash
docker run -d --name blue --network clo835-a1 -p 8081:8080 -e APP_COLOR=blue \
  -e DBHOST=mysql-db -e DBUSER=root -e DBPWD=pw -e DATABASE=employees my_app
docker run -d --name pink --network clo835-a1 -p 8082:8080 -e APP_COLOR=pink \
  -e DBHOST=mysql-db -e DBUSER=root -e DBPWD=pw -e DATABASE=employees my_app
docker run -d --name lime --network clo835-a1 -p 8083:8080 -e APP_COLOR=lime \
  -e DBHOST=mysql-db -e DBUSER=root -e DBPWD=pw -e DATABASE=employees my_app
```

Test them.

```bash
curl http://localhost:8081
curl http://localhost:8082
curl http://localhost:8083
```

Prove the containers find each other by name.

```bash
docker exec blue ping -c 2 pink
docker exec blue ping -c 2 lime
```

## Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `DBHOST` | `localhost` | the MySQL container name |
| `DBPORT` | `3306` | the MySQL port |
| `DBUSER` | `root` | the MySQL user |
| `DBPWD` | `passwors` | the MySQL password |
| `DATABASE` | `employees` | the database name |
| `APP_COLOR` | `lime` | `blue`, `pink` or `lime` |

## The whole stack in one command

`compose.yaml` defines all four services. Compose makes the bridge network for
you, so `DBHOST` is simply the service name `mysql-db`.

```bash
docker compose up -d
docker compose ps
curl http://localhost:8081
curl http://localhost:8082
curl http://localhost:8083
```

Stop it and delete the volume.

```bash
docker compose down -v
```

## Clean up

```bash
docker rm -f blue pink lime mysql-db
docker network rm clo835-a1
```
