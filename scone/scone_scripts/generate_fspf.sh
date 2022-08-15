#!/usr/bin/env bash

# This script runs inside SCONE.
# The following mounted directories are expected:
# - /prepare_source -> The folder that contains the source of the preparation script.
# - /prepare -> The folder that contains the built preparation script.
# - /data_model_original -> The folder that contains the original data model.
# - /data_model -> The folder that will contain the encrypted data model.
# - /fspf -> The folder that will contain the FSPF and related resources.
#   - .../fspf.pb
#   - .../keytag.out
# - /scone_scripts -> The folder that contains this script.

# Paths to useful directories.
SCRIPT_FOLDER=$( dirname -- "$( readlink -f -- "$0"; )"; )
PREPARE_SOURCE_FOLDER=/prepare_source
PREPARE_FOLDER=/prepare
DATA_MODEL_ORIGINAL_FOLDER=/data_model_original
DATA_MODEL_ENCRYPTED_FOLDER=/data_model
FSPF_FOLDER=/fspf
cd "$SCRIPT_FOLDER"

# remove any output files, if present.
cd "$DATA_MODEL_ENCRYPTED_FOLDER"
rm -rf ./*
cd "$FSPF_FOLDER"
rm -rf ./*
cd "$PREPARE_FOLDER"
rm -rf ./*
cd "$SCRIPT_FOLDER"

# copy the prepare.sh script to the prepare folder.
cp $PREPARE_SOURCE_FOLDER/prepare.sh $PREPARE_FOLDER/

# build and copy the sconified CP replica.
cd "$PREPARE_SOURCE_FOLDER/cp-replica"
gcc "./main.c" -o "cp-replica"
mv "cp-replica" "$PREPARE_FOLDER/cp-data"

# Create a FSPF file.
scone fspf create "$FSPF_FOLDER/fspf.pb"

# Mark the file system as a whole as non-protected.
scone fspf addr "$FSPF_FOLDER/fspf.pb" / --kernel / --not-protected

# Mark the PREPARE folder as authenticated.
scone fspf addr "$FSPF_FOLDER/fspf.pb" "$PREPARE_FOLDER" --kernel "$PREPARE_FOLDER" --authenticated
scone fspf addf "$FSPF_FOLDER/fspf.pb" "$PREPARE_FOLDER" "$PREPARE_FOLDER" "$PREPARE_FOLDER"

# Mark the DATA_MODEL_ENCRYPTED folder as encrypted.
scone fspf addr "$FSPF_FOLDER/fspf.pb" "$DATA_MODEL_ENCRYPTED_FOLDER" --kernel "$DATA_MODEL_ENCRYPTED_FOLDER" --encrypted

# Move all files from the DATA_MODEL_ORIGINAL folder to the DATA_MODEL_ENCRYPTED folder.
scone fspf addf "$FSPF_FOLDER/fspf.pb" "$DATA_MODEL_ENCRYPTED_FOLDER" "$DATA_MODEL_ORIGINAL_FOLDER" "$DATA_MODEL_ENCRYPTED_FOLDER"

# Encrypt the FSPF and store its key and tag to a file named 'keytag.out'.
scone fspf encrypt "$FSPF_FOLDER/fspf.pb" > "$FSPF_FOLDER/keytag.out"
