#!/bin/bash

set -e

############################################################
# setup variables
############################################################

export PROJECT_ROOT=/root/test1/

############################################################
# Checking Miner/Sharder counts.
############################################################
pushd ${PROJECT_ROOT} > /dev/null;

    #Miner
    if [[ -f miner/numminers.txt ]] ; then
        MINER=$(cat miner/numminers.txt)
    else
        echo "Checking for Miners."
    fi

    #Sharder
    if [[ -f sharder/numsharder.txt ]] ; then
        SHARDER=$(cat sharder/numsharder.txt)
    else
        echo "Checking for Sharders."
    fi

popd > /dev/null;

############################################################
# Downloading Keygen Binary
############################################################
pushd ${PROJECT_ROOT} > /dev/null;
    if [[ ${SHARDER} -gt 0 || ${MINER} -gt 0 ]] ; then
        if [[ -f bin/keygen ]] ; then
            echo "Keygen binary present"
        else
            wget https://github.com/0chain/onboarding-cli/releases/download/binary%2Fubuntu-18/keygen-linux.tar.gz
            tar -xvf keygen-linux.tar.gz
            rm keygen-linux.tar.gz*
            echo "server_url : http://65.108.96.106:3000/" > server-config.yaml
        fi
    else
        echo "No miner/sharder present."
        exit 1
    fi
popd > /dev/null;

############################################################
# Downloading magicblock for Sharders/Miners
############################################################
pushd ${PROJECT_ROOT} > /dev/null;
    if [[ ${SHARDER} -gt 0 || ${MINER} -gt 0 ]]; then
        echo "Downloading magicblock"
        ./bin/keygen get-magicblock
        ./bin/keygen get-initialstates
    else
        echo "No sharder/miner present"
    fi
popd
