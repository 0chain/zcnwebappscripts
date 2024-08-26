#!/bin/bash

export MINER_SNAP=$1
export SNAP_VERSION=$2 #date

# Stop miner and redis container on the server
echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Stop miner and postgres container on the server.
===============================================================================================================================================================================  \e[39m"
docker stop miner-1 miner-redis-txns-1 miner-redis-1

# Creating snapshot folder
echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Creating snapshot folder to store snapshot.
===============================================================================================================================================================================  \e[39m"
cd ~
mkdir snapshots

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Creating snapshot files.
===============================================================================================================================================================================  \e[39m"
# Downloading snapshot
cd ~/snapshots
rm -rf miner-rocksdb-${SNAP_VERSION}.tar.gz

echo "Creating tar file for miner-rocksdb-${SNAP_VERSION}.tar.gz"
tar -cvf - /var/0chain/miner/ssd/docker.local/miner1/data/rocksdb | pigz -p 10 > miner-rocksdb-${SNAP_VERSION}.tar.gz

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Start miner and postgres container on the server.
===============================================================================================================================================================================  \e[39m"
docker start miner-1 miner-redis-txns-1 miner-redis-1

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Moving snapshot files to zus storage using restic.
===============================================================================================================================================================================  \e[39m"
echo "Set environment variable to zs3server"
export AWS_ACCESS_KEY_ID=rootroot
export AWS_SECRET_ACCESS_KEY=rootroot
export RESTIC_REPOSITORY="s3:http://65.109.152.43:9004/miner/"
export RESTIC_PASSWORD="resticroot"

restic -r s3:http://65.109.152.43:9004/miner/ --verbose backup ./*

if [ $? -eq 0 ]; then
    echo "Snapshot stored to zus successfully."
else
    echo "Snapshot upload failed."
    exit
fi

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Link to docs to deploy miner snapshot.
===============================================================================================================================================================================  \e[39m"
echo "Follow docs to deploy snapshot to bad miner --> https://0chaindocs.gitbook.io/as-onboarding/recovery-from-snapshots/steps-to-apply-snapshot"
