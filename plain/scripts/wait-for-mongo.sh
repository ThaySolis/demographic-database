#!/usr/bin/env bash

mongo --nodb /scripts/wait-for-mongo.js --eval "connectionUrl=\"mongo://localhost:$DB_PORT\""
