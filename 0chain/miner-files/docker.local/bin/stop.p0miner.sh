#!/bin/sh
set -e

PWD=$(pwd)
MINER_DIR=$(basename "$PWD")
MINER_ID=$(echo "$MINER_DIR" | sed -e 's/.*\(.\)$/\1/')

if [ ! -z $1 ]; then
    SSD_PATH=$1
    SSD_PATH+="/docker.local"
else
    SSD_PATH=".."
fi
if [ ! -z $2 ]; then
    HDD_PATH=$2
    HDD_PATH+="/docker.local"
else
    HDD_PATH=".."
fi

# echo $SSD_PATH
# echo $HDD_PATH

echo Starting miner"$MINER_ID" in daemon mode ...

MINER=$MINER_ID PROJECT_ROOT_SSD=$SSD_PATH PROJECT_ROOT_HDD=$HDD_PATH docker-compose -p miner"$MINER_ID" -f ../build.miner/p0docker-compose.yaml down
