#!/bin/bash

set -e

############################################################
# setup variables
############################################################
export PROJECT_ROOT="/var/0chain" # /var/0chain
mkdir -p $PROJECT_ROOT

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        Installing some pre-requisite tools on your server
===============================================================================================================================================================================  \e[39m"
echo -e "\e[32m 1. Apt update. \e[23m \e[0;37m"
sudo apt update
echo -e "\e[32m 2. Installing jq, zip, unzip. \e[23m \e[0;37m"
sudo apt install jq zip unzip -y
echo -ne '\n' | sudo add-apt-repository ppa:ubuntu-toolchain-r/test
echo -e "\e[32m 2. Installing build essentials and gcc. \e[23m \e[0;37m"
sudo apt install build-essential nghttp2 libnghttp2-dev libssl-dev -y
sudo apt install gcc-11 g++-11 -y

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        Persisting Delegate wallet inputs.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;

    #Delegate wallet input
    if [[ -f del_wal_id.txt ]] ; then
        CLIENTID=$(cat del_wal_id.txt)
        echo "Delegate wallet id already exists i.e.: ${CLIENTID}"
    else
        while true; do
            read -p "Do you wish to enter delegate wallet id as an input? Input yes or no. " yn
            case $yn in
                [Yy]* )
                    read -p "Enter the pregenerated delegate wallet id : " CLIENTID
                    sudo sh -c "echo -n ${CLIENTID} > del_wal_id.txt"
                    break;;
                [Nn]* )
                    echo "You entered no. Will create a new delegate wallet for you."
                    break;;
                * )
                    echo "Please answer yes or no.";;
            esac
        done
    fi

popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Generating delegate wallet.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;

    #Delegate Wallet Input
    if [[ -n ${CLIENTID} ]] ; then
        echo "Delegate wallet id found."
        CLIENTID=$(cat del_wal_id.txt)
    else
        echo -e "\e[32m Creating new delegate wallet. \e[23m \e[0;37m"
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
                mkdir bin
                sudo cp -rf zwallet-binary/* ${PROJECT_ROOT}/bin/
                sudo rm -rf zwallet-binary
                echo "block_worker: https://mainnet.zus.network/dns" > config.yaml
                echo "signature_scheme: bls0chain" >> config.yaml
                echo "min_submit: 50" >> config.yaml
                echo "min_confirmation: 50" >> config.yaml
                echo "confirmation_chain_length: 3" >> config.yaml
                echo "max_txn_query: 5" >> config.yaml
                echo "query_sleep_time: 5" >> config.yaml
            else
                echo "Didn't found any Ubuntu version with 20/22."
            fi
        fi
        ./bin/zwallet create-wallet --wallet delegate_wallet.json --configDir . --config config.yaml --silent
        CLIENTID=$( jq -r .client_id delegate_wallet.json )
        sudo sh -c "echo -n ${CLIENTID} > del_wal_id.txt"
    fi
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Verifying wallets for initial stats.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;

    sed -i "s/10000000000/10000000000000/g" ./initial_states.yaml
    if ! grep "f1d14699ccad97ca893a635e68e128b0717f8a1aab1a071db6b40935cbfce90c" initial_states.yaml; then
        cat <<EOF >>initial_states.yaml
      #authorizer01
    - id: f1d14699ccad97ca893a635e68e128b0717f8a1aab1a071db6b40935cbfce90c
      tokens: 10000000000000
      #authorizer02
    - id: 7051ca0cf6f6157a54fa91570d2bb8ab8723b1050381b3d95b66debfdbcf5416
      tokens: 10000000000000
      #authorizer03
    - id: 4de1553b44e4942593b96ca2ee86d543967762929bf6db9c7c65a7446984e6f1
      tokens: 10000000000000
      #authorizer04
    - id: c7cd30d15f713068e65c6469df38d84ec128267bba2c4067360b4d69f208c75e
      tokens: 10000000000000
      #authorizer05
    - id: 37567fc630d9b747364678158df4fcae8d5da2c077681a592ff406c143b5c664
      tokens: 10000000000000
      #authorizer06
    - id: ee1a04d880f03c8f9df25f825a27526a34626dcf9bcffd5c7c182919315e899e
      tokens: 10000000000000
      #authorizer07
    - id: 07aebb92690d3946e5f66b8088ca1fd5e8049dbf203167fc000e22a0a9ea9071
      tokens: 10000000000000
      #authorizer08
    - id: 14b16712cc0d3d2573299a474c0e297616aaea2413709fa8d3d6fda698609142
      tokens: 10000000000000
      #authorizer09
    - id: 5d6bb641dac8fd6d78efe64436ec4b096e2c67ba43386084fe7bce48389a8394
      tokens: 10000000000000
      #authorizer10
    - id: 120501bbbf5f1cbcfb939952e37ef7ff85bf0282031e2ec81edaa5f424242ae8
      tokens: 10000000000000
EOF
    else
        echo "Wallet's already added."
    fi

popd > /dev/null;
