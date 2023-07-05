#!/bin/sh
set -e

BLOBBER_HOST=$1
GF_ADMIN_USER=$2
GF_ADMIN_PASSWORD=$3

# echo $PROJECT_ROOT

echo Deploying monitoring essentials in daemon mode ...

BLOBBER_HOST=${BLOBBER_HOST} GF_ADMIN_USER=${GF_ADMIN_USER} GF_ADMIN_PASSWORD=${GF_ADMIN_PASSWORD} docker-compose -f docker-compose.yaml up -d
