#!/bin/sh
set -e
docker-compose build --progress=plain
docker-compose up -d
exec docker-compose logs -f