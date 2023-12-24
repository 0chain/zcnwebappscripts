#!/bin/bash

set -e

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        Downloading zwallet binary.
===============================================================================================================================================================================  \e[39m"
echo "Generating config.yaml file"
echo "block_worker: https://mainnet.zus.network/dns" > config.yaml
echo "signature_scheme: bls0chain" >> config.yaml
echo "min_submit: 20" >> config.yaml
echo "min_confirmation: 5" >> config.yaml
echo "confirmation_chain_length: 3" >> config.yaml
echo "max_txn_query: 5" >> config.yaml
echo "query_sleep_time: 5" >> config.yaml

if [[ -f bin/zwallet ]] ; then
    echo "zwallet binary already present"
else
    ubuntu_version=$(lsb_release -rs | cut -f1 -d'.')
    if [[ ${ubuntu_version} -eq 18 ]]; then
        echo "Ubuntu 18 is not supported"
        exit 1
    elif [[ ${ubuntu_version} -eq 20 || ${ubuntu_version} -eq 22 ]]; then
        curl -L "https://github.com/0chain/zcnwebappscripts/raw/as-deploy/0chain/artifacts/zwallet-binary.zip" -o /tmp/zwallet-binary.zip
        sudo unzip -o /tmp/zwallet-binary.zip && rm -rf /tmp/zwallet-binary.zip
        mkdir bin || true
        sudo cp -rf zwallet-binary/* bin/
        sudo rm -rf zwallet-binary
    else
        echo "Didn't found any Ubuntu version with 20/22."
    fi
fi

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Fetching and transfering tokens to all delegate wallets
===============================================================================================================================================================================  \e[39m"
i=0
domains=$(jq -r .[].domain others/del_wallets.json)
arr=($domains)
for del_wal in $(jq -r .[].client_id others/del_wallets.json); do
    echo "###################################################################################################################################################################################"
    echo "## SNo.$i :: Transfering 51000 tokens for domain ${arr[i]} to delegate wallet $del_wal from team wallet ##"
    echo "###################################################################################################################################################################################"
    sleep 2s
    ./bin/zwallet send --to_client_id ${del_wal} --tokens 51000 --desc "delegate" --wallet ./team_wallet.json --configDir . --config ./config.yaml
    echo
    echo
    ((i++))
done

############ Steps to run the script ############
# 1. git clone https://github.com/0chain/zcnwebappscripts/tree/as-deploy
# 2. cd zcnwebappscripts
# 3. git checkout as-deploy
# 4. cd 0chain
# 5. copy team_wallet.json to current directory.
# 6. bash transfer_token.sh &> ./transfer_token.log
################################################
