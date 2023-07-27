#!/bin/bash

set -e

############################################################
# setup variables
############################################################
export PROJECT_ROOT="/var/0chain" # /var/0chain
export PROJECT_ROOT_SSD=/var/0chain/miner/ssd # /var/0chain/miner/ssd
export PROJECT_ROOT_HDD=/var/0chain/miner/hdd # /var/0chain/miner/hdd

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
    fi
    echo -e "\e[32m Successfully Created \e[23m \e[0;37m"
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                Persisting Miner inputs.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;

    #DNS Input
    if [[ -f miner/url.txt ]] ; then
        PUBLIC_ENDPOINT=$(cat miner/url.txt)
    fi
    while [[ -z ${PUBLIC_ENDPOINT} ]]
    do
        read -p "Enter the PUBLIC_URL or your domain name. Example: john.mydomain.com : " PUBLIC_ENDPOINT
    done

    #Email Input
    if [[ -f miner/email.txt ]] ; then
        EMAIL=$(cat miner/email.txt)
    fi
    while [[ -z ${EMAIL} ]]
    do
        read -p "Enter the EMAIL: " EMAIL
    done

    #Miner
    if [[ -f miner/numminers.txt ]] ; then
        MINER=$(cat miner/numminers.txt)
    else
        sudo sh -c "echo -n 1 > miner/numminers.txt"
        sudo sh -c "echo -n ${PUBLIC_ENDPOINT} > miner/url.txt"
        sudo sh -c "echo -n ${EMAIL} > miner/email.txt"
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
        echo "server_url : http://65.108.96.106:3000/" | sudo tee server-config.yaml > /dev/null
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
    sudo sh -c "echo "miners:"> config.yaml"
    config 7071
    echo -e "\e[32m Successfully Created \e[23m \e[0;37m"
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                       Generating keys for Miners.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    sudo ./bin/keygen generate-keys --signature_scheme bls0chain --miners 1 --sharders 0
popd > /dev/null;
