#!/bin/bash

set -e

sed -i "s/104/103/g" /var/0chain/server-config.yaml

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                    Setup variables
===============================================================================================================================================================================  \e[39m"

export PROJECT_ROOT="/var/0chain" # /var/0chain
echo -e "\e[32m Successfully Created \e[23m \e[0;37m"

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Checking Miner counts.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;

    #Miner
    if [[ -f miner/numminers.txt ]] ; then
        MINER=$(cat miner/numminers.txt)
    else
        echo "Checking for Miners."
    fi

    echo -e "\e[32m Successfully Checked \e[23m \e[0;37m"

popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Downloading Keygen Binary
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    if [[ ${MINER} -gt 0 ]] ; then
        if [[ -f bin/keygen ]] ; then
            echo -e "\e[32m Keygen binary present \e[23m \e[0;37m"
        else
            wget https://github.com/0chain/onboarding-cli/releases/download/binary%2Fubuntu-18/keygen-linux.tar.gz
            tar -xvf keygen-linux.tar.gz
            rm keygen-linux.tar.gz*
            echo "server_url : https://mb-gen.0chain.net/" > server-config.yaml
        fi
    else
        echo "No miner present."
        exit 1
    fi
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Downloading magicblock for Miners.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    if [[ ${MINER} -gt 0 ]]; then
        sudo ./bin/keygen send-shares || true
        sleep 11s
        sudo ./bin/keygen validate-shares || true
        sleep 11s
        echo "Downloading magicblock"
        sudo ./bin/keygen get-magicblock
        sudo ./bin/keygen get-initialstates
    else
        echo "No miner present"
    fi
popd
