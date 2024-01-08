#!/bin/bash

set -e

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        setup variables
===============================================================================================================================================================================  \e[39m"
export PROJECT_ROOT=/var/0chain # /var/0chain
echo -e "\e[32m Successfully Created \e[23m \e[0;37m"

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        Downloading zwallet binary.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    echo "generating config.yaml file"
    echo "block_worker: https://mainnet.zus.network/dns" > config.yaml
    echo "signature_scheme: bls0chain" >> config.yaml
    echo "min_submit: 20" >> config.yaml
    echo "min_confirmation: 20" >> config.yaml
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
            sudo cp -rf zwallet-binary/* ${PROJECT_ROOT}/bin/
            sudo rm -rf zwallet-binary
        else
            echo "Didn't found any Ubuntu version with 20/22."
        fi
    fi
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        Persisting miner wallets id.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    #Delegate wallet input
    if [[ -f delegate_wallet.json ]] ; then
        CLIENTID=$(cat del_wal_id.txt)
        echo "Delegate wallet id exists i.e.: ${CLIENTID}"
        if [[ -f keys/b0mnode1_keys.json ]] ; then
            MINER_ID=$(jq -r .client_id keys/b0mnode1_keys.json)
        else
            echo "##### Miner wallet not present on your server. Please stake miner manually using delegate_wallet.json using below command. #####"
            echo "./bin/zwallet mn-lock --miner_id <miner-id> --tokens 50000 --configDir . --config ./config.yaml --wallet delegate_wallet.json"
            exit 1
        fi
    else
        echo "##### Delegate wallet not present on your server. Please stake miner manually using delegate_wallet.json using below command. #####"
        echo "./bin/zwallet mn-lock --miner_id <miner-id> --tokens 50000 --configDir . --config ./config.yaml --wallet delegate_wallet.json"
        exit 1
    fi
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Staking miner using delegate wallets.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    echo "./bin/zwallet mn-lock --miner_id ${MINER_ID} --tokens 50000 --configDir . --config ./config.yaml --wallet delegate_wallet.json"
    ./bin/zwallet mn-lock --miner_id ${MINER_ID} --tokens 50000 --configDir . --config ./config.yaml --wallet delegate_wallet.json
popd > /dev/null;


############ Steps to run the script ############
# 1. wget -N https://raw.githubusercontent.com/0chain/zcnwebappscripts/as-deploy/0chain/stake_miner.sh;
# 2. bash miner_sharder.sh &> ./miner_staking.log
################################################
