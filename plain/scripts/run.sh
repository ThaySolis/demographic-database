#!/usr/bin/env bash

export DB_PATH=/data/db

/scripts/create_db.sh

# agora dispara o banco MongoDB.
mongod --auth --dbpath "$DB_PATH" --port "$DB_PORT"
