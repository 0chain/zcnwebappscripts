#!/bin/bash

export TAG=$1
export SHARDER_SNAP=$2
export SNAP_VERSION=$3

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
                                                                            Downloading latest snapshot from the zus storage.
===============================================================================================================================================================================  \e[39m"
# Downloading snapshot
cd /var/0chain/sharder/hdd
mkdir snapshot || true
cd snapshot
echo "Removing previous pulled snapshot if exists"
rm -rf ./*

# echo "Downloading new snapshot"
# wget https://github.com/0chain/zcnwebappscripts/raw/as-deploy/0chain/zwallet-binary/zbox
# chmod +x zbox

# echo "Generating config.yaml file"
# echo "block_worker: https://mainnet.zus.network/dns" > config.yaml
# echo "signature_scheme: bls0chain" >> config.yaml
# echo "min_submit: 20" >> config.yaml
# echo "min_confirmation: 20" >> config.yaml
# echo "confirmation_chain_length: 3" >> config.yaml
# echo "max_txn_query: 5" >> config.yaml
# echo "query_sleep_time: 5" >> config.yaml

# echo "Generating snapshot.json file"
# echo '{"client_id":"e1373e3d129b8d125549ec2527d8515eff7b9b02e6094dff1fe6545b62058041","client_key":"560df578de5a224ac779a8e8e56c469243141171370c59b74a35b994df54c10c411107e97b350a6af9428d63ef42f54b2991880aa2205c7869909534efdab611","keys":[{"public_key":"560df578de5a224ac779a8e8e56c469243141171370c59b74a35b994df54c10c411107e97b350a6af9428d63ef42f54b2991880aa2205c7869909534efdab611","private_key":"94bed72f76cc48517e2f3b5386d0072d4d5c7e88e20300cc9d2385e51a235c01"}],"mnemonics":"auto icon flight enemy culture three field track album kiss accuse weather member diagram symbol where tank doll naive space injury problem blade universe","version":"1.0","date_created":"2024-03-21T12:56:02+01:00","nonce":0}' > snapshot.json

# ./zbox download --remotepath /${SHARDER_SNAP}/sharder-sql2-${SNAP_VERSION}.tar.gz --localpath ./sharder-sql2-${SNAP_VERSION}.tar.gz --allocation a25cde7d0b06655f4f8eb86ec99050eee0b6d929161c62551456acc276adab63 --configDir . --config ./config.yaml --wallet snapshot.json --slient
# ./zbox download --remotepath /${SHARDER_SNAP}/sharder-ssd-sql-${SNAP_VERSION}.tar.gz --localpath ./sharder-ssd-sql-${SNAP_VERSION}.tar.gz --allocation a25cde7d0b06655f4f8eb86ec99050eee0b6d929161c62551456acc276adab63 --configDir . --config ./config.yaml --wallet snapshot.json --slient
# ./zbox download --remotepath /${SHARDER_SNAP}/sharder-mpt-${SNAP_VERSION}.tar.gz --localpath ./sharder-mpt-${SNAP_VERSION}.tar.gz --allocation a25cde7d0b06655f4f8eb86ec99050eee0b6d929161c62551456acc276adab63 --configDir . --config ./config.yaml --wallet snapshot.json --slient

# wget https://zus-snapshots.s3.amazonaws.com/${SHARDER_SNAP}/sharder-blocks-${SNAP_VERSION}.tar.gz
wget https://zus-snapshots.s3.amazonaws.com/${SHARDER_SNAP}/sharder-mpt-${SNAP_VERSION}.tar.gz
wget https://zus-snapshots.s3.amazonaws.com/${SHARDER_SNAP}/sharder-sql2-${SNAP_VERSION}.tar.gz
wget https://zus-snapshots.s3.amazonaws.com/${SHARDER_SNAP}/sharder-ssd-sql-${SNAP_VERSION}.tar.gz

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
