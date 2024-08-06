#!/bin/bash

export TAG=$1
export SNAP_ID=$2
export SNAP_VERSION=$3

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Downloading latest snapshot from the zus storage.
===============================================================================================================================================================================  \e[39m"
# Downloading snapshot
cd /var/0chain/sharder/hdd
mkdir snapshot || true
cd snapshot
echo "Removing previous pulled snapshot if exists"
rm -rf ./*

echo "Installing Restic tool on the server"
sudo apt update -y
sudo apt install restic -y

echo "Set environment variable to zs3server"
export AWS_ACCESS_KEY_ID=rootroot
export AWS_SECRET_ACCESS_KEY=rootroot
export RESTIC_REPOSITORY="s3:http://65.109.152.43:9004/sharder/"
export RESTIC_PASSWORD="resticroot"

restic restore ${SNAP_ID} --target ./

# if [ $? -eq 0 ]; then
#     echo "Snapshot downloaded from zus successfully."
# else
#     echo "Snapshot download failed. Please contact zus team"
#     exit
# fi

# Stopping existing/running sharder and postgres
echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Stop sharder and postgres container on the server.
===============================================================================================================================================================================  \e[39m"
docker rm -f sharder-1 sharder-postgres-1

# Removing and Backup old data
echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Backing up and Removing sharder data from the server.
===============================================================================================================================================================================  \e[39m"
cd /var/0chain/sharder/hdd/docker.local/sharder1/data
if [ -d "./rocksdb_bkp" ]; then
    echo "Removing older hdd /rocksdb_bkp"
    rm -rf rocksdb_bkp
fi
if [ -d "./postgresql2_bkp" ]; then
    echo "Removing older hdd /postgresql2_bkp"
    rm -rf postgresql2_bkp
fi
echo "Backup recent hdd mpt and postgres data"
mv rocksdb rocksdb_bkp || true
mv postgresql2 postgresql2_bkp || true

cd /var/0chain/sharder/ssd/docker.local/sharder1/data
if [ -d "./postgresql_bkp" ]; then
    echo "Removing older ssd /postgresql_bkp"
    rm -rf postgresql_bkp
fi
echo "Backup recent ssd postgres data"
mv postgresql postgresql_bkp || true

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Extracting snapshot files into destination folder.
===============================================================================================================================================================================  \e[39m"
# # extract sharder-blocks.tar.gz
# echo "Extracting sharder-blocks-${SNAP_VERSION}.tar.gz"
# tar -xzvf sharder-blocks-${SNAP_VERSION}.tar.gz

# # Find all .tar.gz files in sharder_blocks and its subdirectories
# echo "Find all .tar.gz files in sharder_blocks and its subdirectories"
# find sharder-blocks -type f -name "*.tar.gz" -print0 | while IFS= read -r -d '' file; do
#     echo "Extracting $file..."
#     tar -xzvf "$file" -C /
# done
cd /var/0chain/sharder/hdd/snapshot/
# extract sharder-mpt.tar.gz to path /var/0chain/sharder/hdd/docker.local/sharder1/data/
echo "extract sharder-mpt-${SNAP_VERSION}.tar.gz to path /var/0chain/sharder/hdd/docker.local/sharder1/data/"
tar -zxvf sharder-mpt-${SNAP_VERSION}.tar.gz -C /

# extract sharder-ssd-sql.tar.gz /var/0chain/sharder/ssd/docker.local/sharder1/data/
echo "extract sharder-ssd-sql-${SNAP_VERSION}.tar.gz /var/0chain/sharder/ssd/docker.local/sharder1/data/"
tar -zxvf sharder-ssd-sql-${SNAP_VERSION}.tar.gz -C /

# extract sharder-sql2.tar.gz /var/0chain/sharder/hdd/docker.local/sharder1/data/
echo "extract sharder-sql2-${SNAP_VERSION}.tar.gz /var/0chain/sharder/hdd/docker.local/sharder1/data/"
tar -zxvf sharder-sql2-${SNAP_VERSION}.tar.gz -C /

# Starting Sharder with snapshot data
yq e -i ".services.sharder.image = \"0chaindev/sharder:${TAG}\"" /var/0chain/sharder/ssd/docker.local/build.sharder/p0docker-compose.yaml
cd /var/0chain/sharder/ssd/docker.local/sharder1/
sudo bash ../bin/start.p0sharder.sh /var/0chain/sharder/ssd /var/0chain/sharder/hdd/
