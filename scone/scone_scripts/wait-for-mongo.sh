#!/usr/bin/env bash

mongo --nodb /scone_scripts/wait-for-mongo.js --eval "connectionUrl=\"mongo://localhost:$DB_PORT\""
