#!/bin/bash

set -e

############################################################
# setup variables
############################################################
export PROJECT_ROOT="/var/0chain" # /var/0chain
export PROJECT_ROOT_SSD=/var/0chain/miner/ssd # /var/0chain/miner/ssd
export PROJECT_ROOT_HDD=/var/0chain/miner/hdd # /var/0chain/miner/hdd

mkdir -p ${PROJECT_ROOT}/miner/ssd

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                Installing some pre-requisite tools on your server
===============================================================================================================================================================================  \e[39m"
echo -e "\e[32m 1. Apt update. \e[23m \e[0;37m"
sudo apt update
echo -e "\e[32m 2. Installing qq. \e[23m \e[0;37m"
sudo apt install -qq -y
echo -e "\e[32m 3. Installing unzip, dnsutils, ufw, ntp, ntpdate. \e[23m \e[0;37m"
sudo apt install unzip dnsutils ufw ntp ntpdate -y
echo -e "\e[32m 4. Installing docker & docker-compose. \e[23m \e[0;37m"
DOCKERCOMPOSEVER=v2.2.3 ; sudo apt install docker.io -y; sudo systemctl enable --now docker ; docker --version	 ; sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKERCOMPOSEVER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose; sudo chmod +x /usr/local/bin/docker-compose ; docker-compose --version
sudo chmod 777 /var/run/docker.sock &> /dev/null
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 || true
sudo chmod a+x /usr/local/bin/yq || true
yq --version || true

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Setting up ntp
===============================================================================================================================================================================  \e[39m"
sudo ufw disable
sudo ufw allow 123/udp
sudo ufw allow out to any port 123
sudo systemctl stop ntp
sudo ntpdate pool.ntp.org
sudo systemctl start ntp
sudo systemctl enable ntp

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

# echo -e "\n\e[93m===============================================================================================================================================================================
#                                                                 Checking URL entered is resolving or not.
# ===============================================================================================================================================================================  \e[39m"
# ipaddr=$(curl api.ipify.org)
# myip=$(dig +short $PUBLIC_ENDPOINT)
# if [[ "$myip" != "$ipaddr" ]]; then
#   echo "$PUBLIC_ENDPOINT IP resolution mistmatch $myip vs $ipaddr"
#   exit 1
# else
#   echo "SUCCESS $PUBLIC_ENDPOINT resolves to $myip"
# fi
