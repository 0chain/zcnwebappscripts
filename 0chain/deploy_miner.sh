#!/bin/bash

set -e

sed -i "s/10000000000/20000000000000000/g" /var/0chain/initial_states.yaml

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        setup variables
===============================================================================================================================================================================  \e[39m"
export PROJECT_ROOT=/var/0chain # /var/0chain
echo -e "\e[32m Successfully Created \e[23m \e[0;37m"

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        Checking Miner counts.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;

    #miner
    if [[ -f miner/numminers.txt ]] ; then
        echo -e "\e[32m Sharder's count present \e[23m \e[0;37m"
        MINER=$(cat miner/numminers.txt)
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
        sudo cp -f b0magicBlock.json miner/ssd/docker.local/config/b0magicBlock_4_miners_2_sharders.json
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
