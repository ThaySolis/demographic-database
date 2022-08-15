#!/usr/bin/env bash

# Paths to useful directories.
SCRIPT_FOLDER=$( dirname -- "$( readlink -f -- "$0"; )"; )

docker build "$SCRIPT_FOLDER" \
    -t "openehr-demographic-database-plain"
