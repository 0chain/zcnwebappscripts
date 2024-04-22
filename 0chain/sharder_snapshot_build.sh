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

# echo -e "\n\e[93m===============================================================================================================================================================================
#                                                                             Copy the snapshot wallet to location ~/snapshots/snapshot.json path.
# ===============================================================================================================================================================================  \e[39m"
# read -p "Press enter after placing snapshot.json wallet to path ~/snapshot/"

# move these zip file to zus blobber storage zus-snapshots/<sharder-snapshot-folder>
echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Moving snapshot files to zus storage.
===============================================================================================================================================================================  \e[39m"
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

# ./zbox upload --localpath ./sharder-sql2-${SNAP_VERSION}.tar.gz --remotepath /${SHARDER_SNAP}/sharder-sql2-${SNAP_VERSION}.tar.gz --allocation a25cde7d0b06655f4f8eb86ec99050eee0b6d929161c62551456acc276adab63 --configDir . --config ./config.yaml --wallet snapshot.json --silent
# ./zbox upload --localpath ./sharder-ssd-sql-${SNAP_VERSION}.tar.gz --remotepath /${SHARDER_SNAP}/sharder-ssd-sql-${SNAP_VERSION}.tar.gz --allocation a25cde7d0b06655f4f8eb86ec99050eee0b6d929161c62551456acc276adab63 --configDir . --config ./config.yaml --wallet snapshot.json --silent
# ./zbox upload --localpath ./sharder-mpt-${SNAP_VERSION}.tar.gz --remotepath /${SHARDER_SNAP}/sharder-mpt-${SNAP_VERSION}.tar.gz --allocation a25cde7d0b06655f4f8eb86ec99050eee0b6d929161c62551456acc276adab63 --configDir . --config ./config.yaml --wallet snapshot.json --silent

# aws s3 cp sharder-blocks-${SNAP_VERSION}.tar.gz s3://zus-snapshots/${SHARDER_SNAP}/
aws s3 cp sharder-sql2-${SNAP_VERSION}.tar.gz s3://zus-snapshots/${SHARDER_SNAP}/
aws s3 cp sharder-ssd-sql-${SNAP_VERSION}.tar.gz s3://zus-snapshots/${SHARDER_SNAP}/
aws s3 cp sharder-mpt-${SNAP_VERSION}.tar.gz s3://zus-snapshots/${SHARDER_SNAP}/

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Link to docs to deploy sharder snapshot.
===============================================================================================================================================================================  \e[39m"
echo "Follow docs to deploy snapshot to bad sharder --> https://0chaindocs.gitbook.io/as-onboarding/recovery-from-snapshots/steps-to-apply-snapshot"

