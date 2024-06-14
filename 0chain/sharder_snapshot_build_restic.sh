#!/bin/bash

export SHARDER_SNAP=$1
export SNAP_VERSION=$2

# Stop sharder and postgres container on the server
echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Stop sharder and postgres container on the server.
===============================================================================================================================================================================  \e[39m"
docker stop sharder-1 sharder-postgres-1

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
rm -rf sharder-sql2-${SNAP_VERSION}.tar.gz
rm -rf sharder-ssd-sql-${SNAP_VERSION}.tar.gz
rm -rf sharder-mpt-${SNAP_VERSION}.tar.gz

echo "Creating tar file for sharder-sql2-${SNAP_VERSION}.tar.gz"
tar -cvf - /var/0chain/sharder/hdd/docker.local/sharder1/data/postgresql2 | pigz -p 10 > sharder-sql2-${SNAP_VERSION}.tar.gz

echo "Creating tar file for sharder-ssd-sql-${SNAP_VERSION}.tar.gz"
tar -cvf - /var/0chain/sharder/ssd/docker.local/sharder1/data/postgresql | pigz -p 10 > sharder-ssd-sql-${SNAP_VERSION}.tar.gz

echo "Creating tar file for sharder-mpt-${SNAP_VERSION}.tar.gz"
tar -cvf - /var/0chain/sharder/hdd/docker.local/sharder1/data/rocksdb | pigz -p 10 > sharder-mpt-${SNAP_VERSION}.tar.gz

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Start sharder and postgres container on the server.
===============================================================================================================================================================================  \e[39m"
docker start sharder-1 sharder-postgres-1

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Moving snapshot files to zus storage using restic.
===============================================================================================================================================================================  \e[39m"
echo "Set environment variable to zs3server"
export AWS_ACCESS_KEY_ID=rootroot
export AWS_SECRET_ACCESS_KEY=rootroot
export RESTIC_REPOSITORY="s3:https://zs3server.zus.network/restic"
export RESTIC_PASSWORD="resticroot"

restic -r s3:https://zs3server.zus.network/restic --verbose backup ./*

if [ $? -eq 0 ]; then
    echo "Snapshot stored to zus successfully."
else
    echo "Snapshot upload failed."
    exit
fi

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Link to docs to deploy sharder snapshot.
===============================================================================================================================================================================  \e[39m"
echo "Follow docs to deploy snapshot to bad sharder --> https://0chaindocs.gitbook.io/as-onboarding/recovery-from-snapshots/steps-to-apply-snapshot"
