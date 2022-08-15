#!/usr/bin/env bash

# Paths to useful directories.
SCRIPT_FOLDER=$( dirname -- "$( readlink -f -- "$0"; )"; )
cd "$SCRIPT_FOLDER"

# erase database files, if any.
mkdir -p "$DB_PATH"
cd "$DB_PATH"
rm -rf ./*
cd "$SCRIPT_FOLDER"

# starts the database and wait until it is ready.
mongod --dbpath "$DB_PATH" --port "$DB_PORT" &
mongo_pid=$!
/scripts/wait-for-mongo.sh

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
