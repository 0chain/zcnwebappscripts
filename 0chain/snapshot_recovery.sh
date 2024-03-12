#!/bin/bash

# Stopping existing/running sharder and postgres
docker rm -f sharder-1 sharder-postgres-1

# Removing old data
cd /var/0chain/sharder/hdd/docker.local/sharder1/
if [ ! -d "./data_backup" ]; then
    echo "Backup /data folder"
    mv data data_backup
else
    echo "removing /data folder"
    rm -rf data
fi

cd /var/0chain/sharder/ssd/docker.local/sharder1/
if [ ! -d "./data_backup" ]; then
    echo "Backup /data folder"
    mv data data_backup
else
    echo "removing /data folder"
    rm -rf data
fi

# Downloading snapshot
cd /var/0chain/sharder/hdd

mkdir snapshot || true
cd snapshot
rm -rf ./*

echo "Removing previous snapshot if exists"
rm sharder-blocks-* || true
rm sharder-mpt-* || true
rm sharder-sql2-* || true
rm sharder-ssd-sql-* || true

echo "Downloading new snapshot"
wget https://zus-snapshots.s3.amazonaws.com/sharder2_0chain_net/sharder-blocks-12-Mar.tar.gz
wget https://zus-snapshots.s3.amazonaws.com/sharder2_0chain_net/sharder-mpt-12-Mar.tar.gz
wget https://zus-snapshots.s3.amazonaws.com/sharder2_0chain_net/sharder-sql2-12-Mar.tar.gz
wget https://zus-snapshots.s3.amazonaws.com/sharder2_0chain_net/sharder-ssd-sql-12-Mar.tar.gz

# extract sharder-blocks.tar.gz
echo "extract sharder-blocks.tar.gz"
tar -xzvf sharder-blocks-12-Mar.tar.gz

# Find all .tar.gz files in sharder_blocks and its subdirectories
echo "Find all .tar.gz files in sharder_blocks and its subdirectories"
find sharder-blocks -type f -name "*.tar.gz" -print0 | while IFS= read -r -d '' file; do
    echo "Extracting $file..."
    tar -xzvf "$file" -C /
done

# extract sharder-mpt.tar.gz to path /var/0chain/sharder/hdd/docker.local/sharder1/data/
echo "extract sharder-mpt.tar.gz to path /var/0chain/sharder/hdd/docker.local/sharder1/data/"
tar -zxvf sharder-mpt-12-Mar.tar.gz -C /

# extract sharder-ssd-sql.tar.gz /var/0chain/sharder/ssd/docker.local/sharder1/data/
echo "extract sharder-ssd-sql.tar.gz /var/0chain/sharder/ssd/docker.local/sharder1/data/"
tar -zxvf sharder-ssd-sql-12-Mar.tar.gz -C /

# extract sharder-sql2.tar.gz /var/0chain/sharder/hdd/docker.local/sharder1/data/
echo "extract sharder-sql2.tar.gz /var/0chain/sharder/hdd/docker.local/sharder1/data/"
tar -zxvf sharder-sql2-12-Mar.tar.gz -C /

# Starting Sharder with snapshot data
yq e -i ".services.sharder.image = \"0chaindev/sharder:v1.13.1 \"" /var/0chain/sharder/ssd/docker.local/build.sharder/p0docker-compose.yaml
cd /var/0chain/sharder/ssd/docker.local/sharder1/
sudo bash ../bin/start.p0sharder.sh /var/0chain/sharder/ssd /var/0chain/sharder/hdd/
