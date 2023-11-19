#!/bin/bash

set -e

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                Installing yq on your server
===============================================================================================================================================================================  \e[39m"
echo -e "\e[32m 1. Setting up yaml query. \e[23m \e[0;37m"
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 || true
sudo chmod a+x /usr/local/bin/yq || true
yq --version || true

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        setup variables
===============================================================================================================================================================================  \e[39m"
export PROJECT_ROOT=/var/0chain # /var/0chain
echo -e "\e[32m Successfully Created \e[23m \e[0;37m"

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        Checking Miner counts.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;

    #Miner
    if [[ -f miner/numminers.txt ]] ; then
        echo -e "\e[32m Sharder's count present \e[23m \e[0;37m"
        MINER=$(cat miner/numminers.txt)
    fi

    #Miner Delegate wallet
    if [[ -f del_wal_id.txt ]] ; then
        echo -e "\e[32m Miner delegate wallet id present \e[23m \e[0;37m"
        MINER_DEL=$(cat del_wal_id.txt)
    else
        echo "Unable to find miner delegate wallet"
        exit 1
    fi

    #checking miner var's
    if [[ -z ${MINER} ]] ; then
        echo -e "\e[32m Miner's not present \e[23m \e[0;37m"
        exit 1
    fi
    echo "hi"
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        Extract miner files
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    curl -L "https://github.com/0chain/zcnwebappscripts/raw/as-deploy/0chain/artifacts/miner-files.zip" -o /tmp/miner-files.zip
    sudo unzip -o /tmp/miner-files.zip && rm -rf /tmp/miner-files.zip
    sudo cp -rf miner-files/* ${PROJECT_ROOT}/miner/ssd/
    sudo rm -rf miner-files
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        Copying configs.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    if [[ ${MINER} -gt 0 ]] ; then
        echo "Copying miner keys & configs."
        sudo cp -rf keys/b0m* miner/ssd/docker.local/config      # miner/ssd/docker.local/config
        sudo cp -rf output/b0m* miner/ssd/docker.local/config
        sudo cp -rf dkgSummary-* miner/ssd/docker.local/config
        sudo cp -f nodes.yaml miner/ssd/docker.local/config/nodes.yaml
        sudo cp -f b0magicBlock.json miner/ssd/docker.local/config/b0magicBlock.json
        sudo cp -f initial_states.yaml miner/ssd/docker.local/config/initial_state.yaml
    fi
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        Executing miner scripts
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT}/miner/ssd > /dev/null;  #/miner/ssd
    if [[ ${MINER} -gt 0 ]]; then
        sudo bash docker.local/bin/init.setup.sh ${PROJECT_ROOT}/miner/ssd ${PROJECT_ROOT}/miner/hdd $MINER
        sudo bash docker.local/bin/setup.network.sh || true
    fi
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Updating for delegate wallet in 0chain.yaml
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT}/miner/ssd > /dev/null;
    yq e -i '.delegate_wallet = "${MINER_DEL}"' ./docker.local/config/0chain.yaml
    echo -e "\e[32m Successfully Updated \e[23m \e[0;37m"
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        Starting miners
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT}/miner/ssd/docker.local > /dev/null;  #/miner/ssd
    for i in $(seq 1 $MINER)
    do
        cd miner${i}
        sudo bash ../bin/start.p0miner.sh ${PROJECT_ROOT}/miner/ssd ${PROJECT_ROOT}/miner/hdd
        cd ../
    done
popd > /dev/null;
