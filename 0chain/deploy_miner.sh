#!/bin/bash

set -e

############################################################
# setup variables
############################################################

export PROJECT_ROOT=/root/test1 # /var/0chain
export PROJECT_ROOT_SSD=/var/0chain/miner/ssd # /var/0chain/miner/ssd
export PROJECT_ROOT_HDD=/var/0chain/miner/hdd # /var/0chain//miner/ssd

############################################################
# Checking Miner counts.
############################################################
pushd ${PROJECT_ROOT} > /dev/null;

    #miner
    if [[ -f miner/numminers.txt ]] ; then
        echo "Checking for Miners."
        MINER=$(cat miner/numminers.txt)
    fi

    #checking miner var's
    if [[ -z ${MINER} ]] ; then
        exit 1
    fi
popd > /dev/null;

############################################################
# Disk setup
############################################################
pushd ${PROJECT_ROOT} > /dev/null;
    mkdir -p disk-setup/
    wget https://raw.githubusercontent.com/0chain/zcnwebappscripts/main/disk-setup/disk_setup.sh -O disk-setup/disk_setup.sh
    wget https://raw.githubusercontent.com/0chain/zcnwebappscripts/main/disk-setup/disk_func.sh -O disk-setup/disk_func.sh

    sudo chmod +x disk-setup/disk_setup.sh
    # bash disk-setup/disk_setup.sh $PROJECT_ROOT_SSD $PROJECT_ROOT_HDD
popd > /dev/null;

############################################################
# Extract miner files
############################################################
pushd ${PROJECT_ROOT} > /dev/null;
    curl -L "https://github.com/0chain/zcnwebappscripts/raw/add/sharder-deploy1/0chain/artifacts/miner-files.zip" -o /tmp/miner-files.zip
    unzip -o /tmp/miner-files.zip && rm -rf /tmp/miner-files.zip
    cp -rf miner-files/* ${PROJECT_ROOT}/miner/ssd/
    rm -rf miner-files
popd > /dev/null;

############################################################
# Copy configs.
############################################################
pushd ${PROJECT_ROOT} > /dev/null;
    if [[ ${MINER} -gt 0 ]] ; then
        echo "Copying miner keys & configs."
        cp -rf keys/b0m* miner/ssd/docker.local/config      # miner/ssd/docker.local/config
        cp -rf output/b0m* miner/ssd/docker.local/config
        cp -rf dkgSummary-* miner/ssd/docker.local/config
        cat nodes.yaml > miner/ssd/docker.local/config/nodes.yaml
        cat b0magicBlock.json > miner/ssd/docker.local/config/b0magicBlock_4_miners_2_sharders.json
        cat initial_states.yaml > miner/ssd/docker.local/config/initial_state.yaml
    fi
popd > /dev/null;

############################################################
# Executing miner scripts
############################################################
pushd ${PROJECT_ROOT}/miner/ssd > /dev/null;  #/miner/ssd
    if [[ ${MINER} -gt 0 ]]; then
        bash docker.local/bin/init.setup.sh ${PROJECT_ROOT}/miner/ssd ${PROJECT_ROOT}/miner/hdd $MINER
        bash docker.local/bin/setup.network.sh || true
    fi
popd > /dev/null;

############################################################
# Starting miners
############################################################
pushd ${PROJECT_ROOT}/miner/ssd/docker.local > /dev/null;  #/miner/ssd
    for i in $(seq 1 $MINER)
    do
        cd miner${i}
        bash ../bin/start.p0miner.sh ${PROJECT_ROOT}/miner/ssd ${PROJECT_ROOT}/miner/hdd
        cd ../
    done
popd > /dev/null;
