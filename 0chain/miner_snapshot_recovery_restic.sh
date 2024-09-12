#!/bin/bash

export TAG=$1 #image_tag
export SNAP_ID=$2 #latest
export SNAP_VERSION=$3 #date

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Downloading latest snapshot from the zus storage.
===============================================================================================================================================================================  \e[39m"
# Downloading snapshots
cd ~
mkdir snapshots || true
cd snapshots
echo "Removing previous pulled snapshots if exists"
rm -rf miner*

echo "Installing Restic tool on the server"
sudo apt update -y
sudo apt install restic -y

echo "Set environment variable to zs3server"
export AWS_ACCESS_KEY_ID=rootroot
export AWS_SECRET_ACCESS_KEY=rootroot
export RESTIC_REPOSITORY="s3:http://65.109.152.43:9004/miner/"
export RESTIC_PASSWORD="resticroot"

restic cache --cleanup
restic restore ${SNAP_ID} --target ./ --verbose

# if [ $? -eq 0 ]; then
#     echo "snapshots downloaded from zus successfully."
# else
#     echo "snapshots download failed. Please contact zus team"
#     exit
# fi

# Stopping existing/running miner and postgres
echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Stop miner and postgres container on the server.
===============================================================================================================================================================================  \e[39m"
docker rm -f miner-1 miner-redis-txns-1 miner-redis-1

# Removing and Backup old data
echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Backing up and Removing miner data from the server.
===============================================================================================================================================================================  \e[39m"
cd /var/0chain/miner/ssd/docker.local/miner1/data/
if [ -d "./rocksdb" ]; then
    echo "Removing older ssd /rocksdb"
    rm -rf rocksdb
fi

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Extracting snapshot files into destination folder.
===============================================================================================================================================================================  \e[39m"
cd ~/snapshots
# extract miner-rocksdb.tar.gz to path /var/0chain/miner/ssd/docker.local/miner1/data/
echo "extract miner-rocksdb-${SNAP_VERSION}.tar.gz to path /var/0chain/miner/ssd/docker.local/miner1/data/rocksdb"
tar -zxvf miner-rocksdb-${SNAP_VERSION}.tar.gz -C /
chmod 777 -R /var/0chain/miner/ssd/docker.local/miner1

# Starting miner with snapshot data
yq e -i ".services.miner.image = \"0chaindev/miner:${TAG}\"" /var/0chain/miner/ssd/docker.local/build.miner/p0docker-compose.yaml
cd /var/0chain/miner/ssd/docker.local/miner1/
sudo bash ../bin/start.p0miner.sh /var/0chain/miner/ssd /var/0chain/miner/hdd
