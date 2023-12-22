#!/bin/bash

set -e

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Downloading zwallet binary.
===============================================================================================================================================================================  \e[39m"
curl -L "https://github.com/0chain/zcnwebappscripts/raw/as-deploy/0chain/artifacts/zwallet-binary.zip" -o /tmp/zwallet-binary.zip
sudo unzip -o /tmp/zwallet-binary.zip && rm -rf /tmp/zwallet-binary.zip
sudo cp -rf zwallet-binary/* .
sudo rm -rf zwallet-binary

echo "block_worker: https://mainnnet.zus.network/dns" > config.yaml
echo "signature_scheme: bls0chain" >> config.yaml
echo "min_submit: 20" >> config.yaml
echo "min_confirmation: 20" >> config.yaml
echo "confirmation_chain_length: 3" >> config.yaml
echo "max_txn_query: 5" >> config.yaml
echo "query_sleep_time: 5" >> config.yaml

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Fetching and transfering tokens to all delegate wallets
===============================================================================================================================================================================  \e[39m"
i=1
for del_wal in $(jq -r .[].client_id others/del_wallets.json); do
    echo "wallet $i --> $del_wal"
    ./zwallet send --to_client_id ${del_wal} --tokens 50001 --desc "delegate" --wallet ./wallet.json --configDir . --config ./config.yaml --silent
    ((i++))
done

