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
    echo "block_worker: https://mainnnet.zus.network/dns" > config.yaml
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
                                                                            Fetching and transfering tokens to all delegate wallets
===============================================================================================================================================================================  \e[39m"
i=0
domains=$(jq -r .[].domain others/del_wallets.json)
arr=($domains)
for del_wal in $(jq -r .[].client_id others/del_wallets.json); do
    echo "wallet $i --> ${arr[i]} --> $del_wal"
    ./zwallet send --to_client_id ${del_wal} --tokens 50001 --desc "delegate" --wallet ./wallet.json --configDir . --config ./config.yaml | tee ./transfer_token.log
    ((i++))
done
