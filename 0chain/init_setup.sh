#!/bin/bash

set -e

############################################################
# setup variables
############################################################
export MINER=3
export SHARDER=3
export PROJECT_ROOT=/root/test1/ # /var/0chain

mkdir -p ${PROJECT_ROOT}

pushd ${PROJECT_ROOT} > /dev/null;
    # rm -rf ./*
    # rm -rf miner/*.txt
    # rm -rf sharder/*.txt
    # rm -rf output
    # rm -rf keys
    # rm -rf config.yaml
    # rm -rf nodes.yaml
    # rm -rf bin
    # rm -rf server-config.yaml

    if [[ ${MINER} -gt 0 ]] ; then
        mkdir -p ${PROJECT_ROOT}/miner/ssd ${PROJECT_ROOT}/miner/hdd
    fi

    if [[ ${SHARDER} -gt 0 ]] ; then
        mkdir -p ${PROJECT_ROOT}/sharder/ssd ${PROJECT_ROOT}/sharder/hdd
    fi

popd

############################################################
# Persisting Miner/Sharder inputs.
############################################################
pushd ${PROJECT_ROOT} > /dev/null;

    #DNS Input
    if [[ -f miner/url.txt && ${MINER} -gt 0 ]] ; then
        PUBLIC_ENDPOINT=$(cat miner/url.txt)
    fi
    if [[ -f sharder/url.txt && ${SHARDER} -gt 0 ]] ; then
        PUBLIC_ENDPOINT=$(cat sharder/url.txt)
    fi
    while [[ -z ${PUBLIC_ENDPOINT} ]]
    do
        read -p "Enter the PUBLIC_URL or your domain name. Example: john.mydomain.com : " PUBLIC_ENDPOINT
    done

    #Email Input
    if [[ -f miner/email.txt && ${MINER} -gt 0 ]] ; then
        EMAIL=$(cat miner/email.txt)
    fi
    if [[ -f sharder/email.txt && ${SHARDER} -gt 0 ]] ; then
        EMAIL=$(cat sharder/email.txt)
    fi
    while [[ -z ${EMAIL} ]]
    do
        read -p "Enter the EMAIL: " EMAIL
    done

    #Miner
    if [[ ${MINER} -gt 0 ]] ; then
        if [[ -f miner/numminers.txt ]] ; then
            MINER=$(cat miner/numminers.txt)
        else
            echo -n ${MINER} > miner/numminers.txt
            echo -n ${PUBLIC_ENDPOINT} > miner/url.txt
            echo -n ${EMAIL} > miner/email.txt
        fi
    fi

    #Sharder
    if [[ ${SHARDER} -gt 0 ]] ; then
        if [[ -f sharder/numsharder.txt ]] ; then
            SHARDER=$(cat sharder/numsharder.txt)
        else
            echo -n ${SHARDER} > sharder/numsharder.txt
            echo -n ${PUBLIC_ENDPOINT} > sharder/url.txt
            echo -n ${EMAIL} > sharder/email.txt
        fi
    fi

popd > /dev/null;

############################################################
# Checking URL entered is resolving or not
############################################################
# ipaddr=$(curl api.ipify.org)
# myip=$(dig +short $PUBLIC_ENDPOINT)
# if [[ "$myip" != "$ipaddr" ]]
# then
#   echo "$PUBLIC_ENDPOINT IP resolution mistmatch $myip vs $ipaddr"
#   exit 1
# else
#   echo "SUCCESS $PUBLIC_ENDPOINT resolves to $myip"
# fi

############################################################
# Downloading Keygen Binary
############################################################
pushd ${PROJECT_ROOT} > /dev/null;
    if [[ -f bin/keygen ]] ; then
        echo "Keygen binary already present"
    else
        wget https://github.com/0chain/onboarding-cli/releases/download/binary%2Fubuntu-18/keygen-linux.tar.gz
        tar -xvf keygen-linux.tar.gz
        rm keygen-linux.tar.gz*
        echo "server_url : http://65.108.96.106:3000/" > server-config.yaml
    fi
    # echo "server_url : http://65.108.96.106:3000/" > server-config.yaml
popd > /dev/null;

############################################################
# Creating config.yaml file
############################################################
config() {
    echo "  - n2n_ip: ${PUBLIC_ENDPOINT}
    public_ip: ${PUBLIC_ENDPOINT}
    port: $1
    description: ${EMAIL}" >> config.yaml
}

pushd ${PROJECT_ROOT} > /dev/null;
    #Miners Only
    if [[ ${MINER} -gt 0 && ${SHARDER} -eq 0 ]] ; then
        echo "miners:"> config.yaml
        for i in $(seq 1 ${MINER}); do
            config 707$i
        done
    fi
    #Sharders Only
    if [[ ${SHARDER} -gt 0 && ${MINER} -eq 0 ]] ; then
        echo "sharders:" > config.yaml
        for i in $(seq 1 ${SHARDER}); do
            config 717$i
        done
    fi
    #Sharders & Miners both
    if [[ ${SHARDER} -gt 0 && ${MINER} -gt 0 ]]; then
        echo "miners:"> config.yaml
        for i in $(seq 1 ${MINER}); do
            config 707$i
        done
        echo "sharders:" >> config.yaml
        for i in $(seq 1 ${SHARDER}); do
            config 717$i
        done
    fi
popd > /dev/null;

############################################################
# Generating keys for Sharders/Miners
############################################################
pushd ${PROJECT_ROOT} > /dev/null;
    ./bin/keygen generate-keys --signature_scheme bls0chain --miners ${MINER} --sharders ${SHARDER}
    if [[ ${MINER} -gt 0 ]]; then
        sleep 10s
        ./bin/keygen send-shares
        sleep 10s
        ./bin/keygen validate-shares
    fi
popd
