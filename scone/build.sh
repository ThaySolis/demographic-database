#!/usr/bin/env bash

# Determines the SGX device.
# Adapted from <https://sconedocs.github.io/sgxinstall/#determine-sgx-device>
export SGXDEVICE="/dev/sgx/enclave"
export MOUNT_SGXDEVICE="--device=/dev/sgx/enclave --device=/dev/sgx/provision"
export SCONE_MODE="hw"
if [[ ! -e "$SGXDEVICE" ]] ; then
    export SGXDEVICE="/dev/sgx"
    export MOUNT_SGXDEVICE="--device=/dev/sgx"
    if [[ ! -e "$SGXDEVICE" ]] ; then
        export SGXDEVICE="/dev/isgx"
        export MOUNT_SGXDEVICE="--device=/dev/isgx"
        if [[ ! -c "$SGXDEVICE" ]] ; then
            echo "Warning: No SGX device found! Will run in SIM mode." > /dev/stderr
            export MOUNT_SGXDEVICE=""
            export SGXDEVICE=""
            export SCONE_MODE="sim"
        fi
    fi
fi

# SCONE images
MONGO_PLAIN_IMAGE=mongo:3.4.4
MONGO_SCONE_IMAGE=registry.scontain.com:5050/sconecuratedimages/apps:mongodb-3.4.4-alpine-scone5.3.0
COMPILERS_SCONE_IMAGE=registry.scontain.com:5050/sconecuratedimages/crosscompilers

# CAS configuration.
CAS_ADDR=5-7-0.scone-cas.cf
CAS_MRENCLAVE="3061b9feb7fa67f3815336a085f629a13f04b0a1667c93b14ff35581dc8271e4"

# Paths to useful directories.
SCRIPT_FOLDER=$( dirname -- "$( readlink -f -- "$0"; )"; )
SOURCE_FOLDER=$SCRIPT_FOLDER/..
RESOURCES_FOLDER=$SCRIPT_FOLDER/_resources
PREPARE_SOURCE_FOLDER=$SCRIPT_FOLDER/prepare_source
PREPARE_FOLDER=$RESOURCES_FOLDER/prepare
DATA_MODEL_ORIGINAL_FOLDER=$RESOURCES_FOLDER/data_model_original
DATA_MODEL_ENCRYPTED_FOLDER=$RESOURCES_FOLDER/data_model_encrypted
FSPF_FOLDER=$RESOURCES_FOLDER/fspf
CAS_SESSION_FOLDER=$RESOURCES_FOLDER/cas_session
SCONE_SCRIPTS_FOLDER=$SCRIPT_FOLDER/scone_scripts

# Load variables from the .env file.
# source: https://gist.github.com/mihow/9c7f559807069a03e302605691f85572?permalink_comment_id=3770590#gistcomment-3770590
export $(echo $(cat "$SOURCE_FOLDER/.env" | sed 's/#.*//g'| xargs) | envsubst)

# Generate the data folder if it does not exist.
mkdir -p "$RESOURCES_FOLDER"

# Make sure the output folders exists.
mkdir -p "$PREPARE_FOLDER"
mkdir -p "$DATA_MODEL_ORIGINAL_FOLDER"
mkdir -p "$DATA_MODEL_ENCRYPTED_FOLDER"
mkdir -p "$FSPF_FOLDER"
mkdir -p "$CAS_SESSION_FOLDER"

# Run the container which generates the data model.
docker run -it --rm \
    -e "DB_USERNAME=$DB_USERNAME" \
    -e "DB_PASSWORD=$DB_PASSWORD" \
    -v "$SCONE_SCRIPTS_FOLDER:/scone_scripts" \
    -v "$DATA_MODEL_ORIGINAL_FOLDER:/data_mongo" \
    "$MONGO_PLAIN_IMAGE" \
    "/scone_scripts/create_db.sh"

# Run the container which generates the FSPF and encrypts files.
docker run -it --rm \
    $MOUNT_SGXDEVICE -e "SCONE_MODE=$SCONE_MODE" \
    -v "$PREPARE_SOURCE_FOLDER:/prepare_source" \
    -v "$PREPARE_FOLDER:/prepare" \
    -v "$DATA_MODEL_ORIGINAL_FOLDER:/data_model_original" \
    -v "$DATA_MODEL_ENCRYPTED_FOLDER:/data_model" \
    -v "$FSPF_FOLDER:/fspf" \
    -v "$SCONE_SCRIPTS_FOLDER/:/scone_scripts" \
    "$COMPILERS_SCONE_IMAGE" \
    "/scone_scripts/generate_fspf.sh"

# Extract the generated key and tag.
SCONE_FSPF_KEY=$(cat "$FSPF_FOLDER/keytag.out" | awk '{print $11}')
SCONE_FSPF_TAG=$(cat "$FSPF_FOLDER/keytag.out" | awk '{print $9}')

# Generates a certificate-key pair to authenticate with the CAS.
rm -f "$CAS_SESSION_FOLDER/cas-cert.pem"
rm -f "$CAS_SESSION_FOLDER/cas-key.pem"
openssl req -newkey rsa:4096 -days 365 -nodes -x509 \
    -out "$CAS_SESSION_FOLDER/cas-cert.pem" \
    -keyout "$CAS_SESSION_FOLDER/cas-key.pem" \
    -config "$SCRIPT_FOLDER/cas-certreq.conf"

# copy the session template to the CAS session folder.
cp -f "$SCRIPT_FOLDER/cas-session-template.yml" "$CAS_SESSION_FOLDER/"

# Run the container which generates the session with the CAS.
docker run -it --rm \
    $MOUNT_SGXDEVICE -e "SCONE_MODE=$SCONE_MODE" \
    --env-file "$SOURCE_FOLDER/.env" \
    -e "FSPF_KEY=$SCONE_FSPF_KEY" \
    -e "FSPF_TAG=$SCONE_FSPF_TAG" \
    -e "CAS_ADDR=$CAS_ADDR" \
    -e "CAS_MRENCLAVE=$CAS_MRENCLAVE" \
    -v "$PREPARE_FOLDER:/prepare" \
    -v "$CAS_SESSION_FOLDER:/cas_session" \
    -v "$SCONE_SCRIPTS_FOLDER/:/scone_scripts" \
    "$MONGO_SCONE_IMAGE" \
    "/scone_scripts/generate_session.sh"

# Generate the Dockerfile
cat > "$SCRIPT_FOLDER/Dockerfile" <<EOF
FROM $MONGO_SCONE_IMAGE

COPY _resources/data_model_encrypted /data_model
COPY _resources/prepare /prepare

RUN mkdir /fspf
COPY _resources/fspf/fspf.pb /fspf/

WORKDIR /prepare

EXPOSE $DB_PORT

CMD /prepare/prepare.sh && mongod --auth --dbpath "/data_mongo/db" --port "$DB_PORT" --bind_ip 0.0.0.0
EOF

# Finally, build the container image.
# Build the Docker image.
docker build "$SCRIPT_FOLDER" \
    -t "openehr-demographic-database-scone"

# Generate the script to run the container locally, without LAS and CAS.
cat > "$SCRIPT_FOLDER/run-sim.sh" <<EOF
#!/usr/bin/env bash

# Run the container
docker run -it --rm \
    --name "openehr-demographic-database" \
    -e "SCONE_MODE=sim" \
    -e "SCONE_FSPF=/fspf/fspf.pb" \
    -e "SCONE_FSPF_KEY=$SCONE_FSPF_KEY" \
    -e "SCONE_FSPF_TAG=$SCONE_FSPF_TAG" \
    --network host \
    "openehr-demographic-database-scone"
EOF