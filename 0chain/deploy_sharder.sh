#!/bin/bash

set -e

############################################################
# setup variables
############################################################

export PROJECT_ROOT=/root/test1 # /var/0chain
export PROJECT_ROOT_SSD=/var/0chain/sharder/ssd # /var/0chain/sharder/ssd
export PROJECT_ROOT_HDD=/var/0chain/sharder/hdd # /var/0chain/sharder/ssd

############################################################
# Checking Sharder counts.
############################################################
pushd ${PROJECT_ROOT} > /dev/null;
    #Sharder
    if [[ -f sharder/numsharder.txt ]] ; then
        echo "Checking for Sharders."
        SHARDER=$(cat sharder/numsharder.txt)
    fi

    #Checking shader var's
    if [[ -z ${SHARDER} ]] ; then
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
# Extract sharder files
############################################################
pushd ${PROJECT_ROOT} > /dev/null;
    curl -L "https://github.com/0chain/zcnwebappscripts/raw/add/sharder-deploy1/0chain/artifacts/sharder-files.zip" -o /tmp/sharder-files.zip
    unzip -o /tmp/sharder-files.zip && rm -rf /tmp/sharder-files.zip
    cp -rf sharder-files/* ${PROJECT_ROOT}/sharder/ssd/
    rm -rf sharder-files
popd > /dev/null;

############################################################
# Copy configs.
############################################################
pushd ${PROJECT_ROOT} > /dev/null;
    if [[ ${SHARDER} -gt 0 ]] ; then
        echo "Copying sharder keys & configs."
        cp -rf keys/b0s* sharder/ssd/docker.local/config    # sharder/ssd/docker.local/config
        cat nodes.yaml > sharder/ssd/docker.local/config/nodes.yaml
        cat b0magicBlock.json > sharder/ssd/docker.local/config/b0magicBlock_4_miners_2_sharders.json
        cat initial_states.yaml > sharder/ssd/docker.local/config/initial_state.yaml
    fi
popd > /dev/null;

############################################################
# Executing sharder scripts
############################################################
pushd ${PROJECT_ROOT}/sharder/ssd > /dev/null;  #/sharder/ssd
    if [[ ${SHARDER} -gt 0 ]]; then
        bash docker.local/bin/init.setup.sh ${PROJECT_ROOT}/sharder/ssd ${PROJECT_ROOT}/sharder/hdd $SHARDER
        bash docker.local/bin/setup.network.sh || true
    fi
popd > /dev/null;

############################################################
# Starting sharders
############################################################
pushd ${PROJECT_ROOT}/sharder/ssd/docker.local > /dev/null;  #/sharder/ssd
    for i in $(seq 1 $SHARDER)
    do
        cd sharder${i}
        bash ../bin/start.p0sharder.sh ${PROJECT_ROOT}/sharder/ssd ${PROJECT_ROOT}/sharder/hdd
        cd ../
    done
popd > /dev/null;
