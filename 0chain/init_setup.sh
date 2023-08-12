#!/bin/bash

set -e

############################################################
# setup variables
############################################################
export MINER=3
export SHARDER=2
export PROJECT_ROOT="/root/test" # /var/0chain
export PROJECT_ROOT_SSD=/root/test/sharder/ssd # /var/0chain/sharder/ssd
export PROJECT_ROOT_HDD=/root/test/sharder/hdd # /var/0chain/sharder/ssd

mkdir -p ${PROJECT_ROOT}

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                Installing some pre-requisite tools on your server 
===============================================================================================================================================================================  \e[39m"
echo -e "\e[32m 1. Apt update. \e[23m \e[0;37m"
sudo apt update
echo -e "\e[32m 2. Installing qq. \e[23m \e[0;37m"
sudo apt install -qq -y
echo -e "\e[32m 3. Installing unzip, dnsutils. \e[23m \e[0;37m"
sudo apt install unzip dnsutils -y
echo -e "\e[32m 4. Installing docker & docker-compose. \e[23m \e[0;37m"
DOCKERCOMPOSEVER=v2.2.3 ; sudo apt install docker.io -y; sudo systemctl enable --now docker ; docker --version	 ; sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKERCOMPOSEVER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose; sudo chmod +x /usr/local/bin/docker-compose ; docker-compose --version
sudo chmod 777 /var/run/docker.sock &> /dev/null

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                Checking docker service running or not
===============================================================================================================================================================================  \e[39m"
echo -e "\e[32m 1. Docker status. \e[23m"
if (systemctl is-active --quiet docker) ; then
    echo -e "\e[32m  docker is running fine. \e[23m \n"
else
    echo -e "\e[31m  $REQUIRED_PKG is failing to run. Please check and resolve it first. You can connect with team for support too. \e[13m \n"
    exit 1
fi

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Disk setup 
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    if [[ ! -d ${PROJECT_ROOT_HDD} || ! -d ${PROJECT_ROOT_SSD} ]]; then
        sudo mkdir -p disk-setup/
        sudo wget https://raw.githubusercontent.com/0chain/zcnwebappscripts/main/disk-setup/disk_setup.sh -O disk-setup/disk_setup.sh
        sudo wget https://raw.githubusercontent.com/0chain/zcnwebappscripts/main/disk-setup/disk_func.sh -O disk-setup/disk_func.sh

        sudo chmod +x disk-setup/disk_setup.sh
        bash disk-setup/disk_setup.sh $PROJECT_ROOT_SSD $PROJECT_ROOT_HDD
    else
        rm -rf ./*
        rm -rf miner/*.txt
        rm -rf sharder/*.txt
        rm -rf output
        rm -rf keys
        rm -rf config.yaml
        rm -rf nodes.yaml
        rm -rf bin
        rm -rf server-config.yaml

        if [[ ${SHARDER} -gt 0 ]] ; then
            sudo mkdir -p ${PROJECT_ROOT}/sharder/ssd ${PROJECT_ROOT}/sharder/hdd
        fi
    fi
    if [[ ${MINER} -gt 0 ]] ; then
        sudo mkdir -p ${PROJECT_ROOT}/miner/ssd ${PROJECT_ROOT}/miner/hdd
    fi
    echo -e "\e[32m Successfully Created \e[23m \e[0;37m"
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                Persisting Miner/Sharder inputs. 
===============================================================================================================================================================================  \e[39m"
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
            sudo sh -c "echo -n ${MINER} > miner/numminers.txt"
            sudo sh -c "echo -n ${PUBLIC_ENDPOINT} > miner/url.txt"
            sudo sh -c "echo -n ${EMAIL} > miner/email.txt"
        fi
    fi

    #Sharder
    if [[ ${SHARDER} -gt 0 ]] ; then
        if [[ -f sharder/numsharder.txt ]] ; then
            SHARDER=$(cat sharder/numsharder.txt)
        else
            sudo sh -c "echo -n ${SHARDER} > sharder/numsharder.txt"
            sudo sh -c "echo -n ${PUBLIC_ENDPOINT} > sharder/url.txt"
            sudo sh -c "echo -n ${EMAIL} > sharder/email.txt"
        fi
    fi
    echo -e "\e[32m Successfully Completed \e[23m \e[0;37m"

popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                Checking URL entered is resolving or not.
===============================================================================================================================================================================  \e[39m"
ipaddr=$(curl api.ipify.org)
myip=$(dig +short $PUBLIC_ENDPOINT)
if [[ "$myip" != "$ipaddr" ]]; then
  echo "$PUBLIC_ENDPOINT IP resolution mistmatch $myip vs $ipaddr"
  exit 1
else
  echo "SUCCESS $PUBLIC_ENDPOINT resolves to $myip"
fi

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                       Downloading Keygen Binary.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    if [[ -f bin/keygen ]] ; then
        echo "Keygen binary already present"
    else
        ubuntu_version=$(lsb_release -rs | cut -f1 -d'.')
        if [[ ${ubuntu_version} -eq 18 ]]; then
            sudo wget https://github.com/0chain/onboarding-cli/releases/download/binary%2Fubuntu18/keygen-linux.tar.gz
        elif [[ ${ubuntu_version} -eq 20 || ${ubuntu_version} -eq 22 ]]; then
            sudo wget https://github.com/0chain/onboarding-cli/releases/download/refactor%2Fnode-path/keygen-linux.tar.gz
        else
            echo "Didn't found any Ubuntu version with 18/20/22."
        fi
        sudo tar -xvf keygen-linux.tar.gz
        sudo rm keygen-linux.tar.gz*
        echo "server_url : https://mb-gen.0chain.net/" | sudo tee server-config.yaml > /dev/null
        echo "T: 2" | sudo tee -a server-config.yaml > /dev/null
        echo "N: 3" | sudo tee -a server-config.yaml > /dev/null
        echo "K: 3" | sudo tee -a server-config.yaml > /dev/null
    fi
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                       Creating config.yaml file.
===============================================================================================================================================================================  \e[39m"
config() {
    echo "  - n2n_ip: ${PUBLIC_ENDPOINT}" | sudo tee -a config.yaml > /dev/null
    echo "    public_ip: ${PUBLIC_ENDPOINT}" | sudo tee -a config.yaml > /dev/null
    echo "    port: $1" | sudo tee -a config.yaml > /dev/null
    echo "    description: ${EMAIL}" | sudo tee -a config.yaml > /dev/null
}

pushd ${PROJECT_ROOT} > /dev/null;
    #Miners Only
    if [[ ${MINER} -gt 0 && ${SHARDER} -eq 0 ]] ; then
        sudo sh -c "echo "miners:"> config.yaml"
        for i in $(seq 1 ${MINER}); do
            config 707$i
        done
    fi
    #Sharders Only
    if [[ ${SHARDER} -gt 0 && ${MINER} -eq 0 ]] ; then
        sudo sh -c "echo "sharders:" > config.yaml"
        for i in $(seq 1 ${SHARDER}); do
            config 717$i
        done
    fi
    #Sharders & Miners both
    if [[ ${SHARDER} -gt 0 && ${MINER} -gt 0 ]]; then
        sudo sh -c "echo "miners:"> config.yaml"
        for i in $(seq 1 ${MINER}); do
            config 707$i
        done
        sudo sh -c "echo "sharders:" >> config.yaml"
        for i in $(seq 1 ${SHARDER}); do
            config 717$i
        done
    fi
    echo -e "\e[32m Successfully Created \e[23m \e[0;37m"
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                       Generating keys for Sharders/Miners.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    sudo ./bin/keygen generate-keys --signature_scheme bls0chain --miners ${MINER} --sharders ${SHARDER}
popd > /dev/null;
