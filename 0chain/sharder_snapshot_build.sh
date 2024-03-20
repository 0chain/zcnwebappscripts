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

# echo "Creating tar files for sharder-blocks-${SNAP_VERSION} files"
# for ((idx=0; idx<=15; idx++))
# do
#   hex=$(printf "%x" $idx)
#   echo "pack $hex"
#   mkdir -p sharder-blocks-${SNAP_VERSION}/$hex
#   packss -path /var/0chain/sharder/hdd/docker.local/sharder1/data/blocks/$hex -dest sharder-blocks-${SNAP_VERSION}/$hex -thread 36
#   # go run main.go -path /var/0chain/sharder/hdd/docker.local/sharder1/data/blocks/$hex -dest sharder-blocks-${SNAP_VERSION}/$hex --depth 2 --thread 25
# done

# echo "Creating tar file for sharder-blocks-${SNAP_VERSION}.tar.gz"
# tar -cvf - sharder-blocks-${SNAP_VERSION} | pigz -p 10 > sharder-blocks-${SNAP_VERSION}.tar.gz

# Start sharder and postgres container on the server
echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Start sharder and postgres container on the server.
===============================================================================================================================================================================  \e[39m"
docker start sharder-1 sharder-postgres-1

# move these zip file to s3 bucket zus-snapshots/<sharder-snapshot-folder>
echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Moving snapshot files to s3.
===============================================================================================================================================================================  \e[39m"
# aws s3 cp sharder-blocks-${SNAP_VERSION}.tar.gz s3://zus-snapshots/${SHARDER_SNAP}/
aws s3 cp sharder-sql2-${SNAP_VERSION}.tar.gz s3://zus-snapshots/${SHARDER_SNAP}/
aws s3 cp sharder-ssd-sql-${SNAP_VERSION}.tar.gz s3://zus-snapshots/${SHARDER_SNAP}/
aws s3 cp sharder-mpt-${SNAP_VERSION}.tar.gz.tar.gz s3://zus-snapshots/${SHARDER_SNAP}/

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Link to docs to deploy sharder snapshot.
===============================================================================================================================================================================  \e[39m"
echo "Follow docs to deploy snapshot to bad sharder --> https://0chaindocs.gitbook.io/as-onboarding/recovery-from-snapshots/steps-to-apply-snapshot"