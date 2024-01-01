#!/bin/bash

set -e

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        setup variables
===============================================================================================================================================================================  \e[39m"
export PROJECT_ROOT=/var/0chain # /var/0chain
echo -e "\e[32m Successfully set \e[23m \e[0;37m"

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        updating --num_delegates to 1 on both sharder and miner.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    if [[ -f delegate_wallet.json ]] ; then
        if [[ -f keys/b0mnode1_keys.json ]] ; then
            echo -e "\e[32m Updating miner \e[23m \e[0;37m"
            prov_min_id=$(jq -r .client_id keys/b0mnode1_keys.json)
            ./bin/zwallet mn-update-settings --id ${prov_min_id} --num_delegates 1 --configDir . --config ./config.yaml --wallet delegate_wallet.json
        elif [[ -f keys/b0snode1_keys.json ]] ; then
            echo -e "\e[32m Updating sharder \e[23m \e[0;37m"
            prov_shar_id=$(jq -r .client_id keys/b0snode1_keys.json)
            ./bin/zwallet mn-update-settings --sharder true --id ${prov_shar_id} --num_delegates 1 --configDir . --config ./config.yaml --wallet delegate_wallet.json
        else
            echo -e "\e[31m didn't found sharder/miner keys on the server. Please connect with zus team. \e[13m \e[0;37m"
            exit 1
        fi
    else
        echo -e "\e[31m ##### Delegate wallet not present on your server. Please run below command manually after replacing your provider id using delegate_wallet.json. ##### \e[13m \e[0;37m"
        echo -e "\e[32m ./bin/zwallet mn-update-settings --id <sharder-id> --num_delegates 1 --configDir . --config ./config.yaml --wallet delegate_wallet.json \e[23m \e[0;37m"
        exit 1
    fi
popd > /dev/null;
