#!/usr/bin/env bash

STATUS_FILE_FOLDER=/data_mongo
STATUS_FILE=$STATUS_FILE_FOLDER/READY

if [ ! -f "$STATUS_FILE" ]
then
    mkdir -p "$STATUS_FILE_FOLDER"
    /prepare/cp-data
    touch "$STATUS_FILE"
    sleep 1
fi
