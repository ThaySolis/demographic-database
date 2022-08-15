#!/usr/bin/env bash

# This script runs inside SCONE.
# The following mounted directories are expected:
# - /data_mongo -> The folder that contains the database files
# - /scone_scripts -> The folder that contains this script.

# The following environment variables are expected:
# - DB_USERNAME
# - DB_PASSWORD

# Paths to useful directories.
SCRIPT_FOLDER=$( dirname -- "$( readlink -f -- "$0"; )"; )
DATA_FOLDER=/data_mongo
cd "$SCRIPT_FOLDER"

# Database configuration.
export DB_PATH=$DATA_FOLDER/db
export DB_PORT=27017

# erase database files, if any.
mkdir -p "$DATA_FOLDER"
cd "$DATA_FOLDER"
rm -rf ./*
cd "$SCRIPT_FOLDER"

# make sure the database folder exists.
mkdir -p "$DB_PATH"

# starts the database and wait until it is ready.
mongod --dbpath "$DB_PATH" --port "$DB_PORT" &
mongo_pid=$!
/scone_scripts/wait-for-mongo.sh

# creates the user and the collections.
mongo --port "$DB_PORT" <<EOF
use admin
db.createUser({
    user: "$DB_USERNAME",
    pwd: "$DB_PASSWORD",
    roles: [
        "userAdminAnyDatabase",
        "dbAdminAnyDatabase",
        "readWriteAnyDatabase",
        "root",
        { role: "dbAdmin", db: "demographic" },
        { role: "readWrite", db: "demographic" }
    ]
});

use demographic
db.createCollection("patients");
db.createCollection("contributions");

use admin
db.shutdownServer();
EOF

# waits until the database is shut down.
wait $mongo_pid

# wait one extra second just in case.
sleep 1
