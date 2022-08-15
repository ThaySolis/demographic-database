#!/usr/bin/env bash

# Paths to useful directories.
SCRIPT_FOLDER=$( dirname -- "$( readlink -f -- "$0"; )"; )
SOURCE_FOLDER=$SCRIPT_FOLDER/..
RESOURCES_FOLDER=$SCRIPT_FOLDER/_resources
VOLUME_DATA_FOLDER=$RESOURCES_FOLDER/volume_data

# Make sure the VOLUME folders exists.
mkdir -p "$VOLUME_DATA_FOLDER"

docker run -it --rm \
    --env-file "$SOURCE_FOLDER/.env" \
    --name "openehr-demographic-database" \
    -v "$VOLUME_DATA_FOLDER:/data" \
    --network host \
    "openehr-demographic-database-plain"
