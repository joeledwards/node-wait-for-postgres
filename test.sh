#!/bin/bash

set -x

IMAGE_ID="postgres:9.5.3"
CONTAINER_NAME="pg-query-runner"
SQL_FILE="test-queries.sql"
PG_USERNAME="test"
PG_PASSWORD="test"
PG_DATABASE="test"

docker kill $CONTAINER_NAME
docker rm $CONTAINER_NAME

docker run \
  -e POSTGRES_USER=$PG_USERNAME \
  -e POSTGRES_PASSWORD=$PG_PASSWORD \
  -e POSTGRES_DB=$PG_DATABASE \
  --name=$CONTAINER_NAME \
  -P -d $IMAGE_ID

PG_HOST=`docker inspect -f '{{ .NetworkSettings.IPAddress }}' ${CONTAINER_NAME}`
PG_PORT=5432

echo "host: ${PG_HOST}"
echo "port: ${PG_PORT}"
echo "user: ${PG_USERNAME}"
echo "pass: ${PG_PASSWORD}"
echo "  db: ${PG_DATABASE}"

coffee src/index.coffee \
  --query="SELECT 1" \
  --host=$PG_HOST \
  --port=$PG_PORT \
  --username=$PG_USERNAME \
  --password=$PG_PASSWORD \
  --database=$PG_DATABASE \
  --connect-timeout=333 \
  --total-timeout=30000

docker kill $CONTAINER_NAME
docker rm $CONTAINER_NAME

