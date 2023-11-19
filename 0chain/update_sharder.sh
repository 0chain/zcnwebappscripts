#!/bin/bash

set -e

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                setup variables & yq
===============================================================================================================================================================================  \e[39m"
export PROJECT_ROOT=/var/0chain # /var/0chain

sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 || true
sudo chmod a+x /usr/local/bin/yq || true
yq --version || true

echo -e "\e[32m Successfully Created \e[23m \e[0;37m"

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Checking Sharder counts.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    #Sharder
    if [[ -f sharder/numsharder.txt ]] ; then
        echo -e "\e[32m Sharders count present \e[23m \e[0;37m"
        SHARDER=$(cat sharder/numsharder.txt)
    fi

    #Checking shader var's
    if [[ -z ${SHARDER} ]] ; then
        echo -e "\e[32m Sharder's not present' \e[23m \e[0;37m"
        exit 1
    fi
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Updating image sharder image tag
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT}/sharder/ssd > /dev/null;
    yq e -i '.services.sharder.image = "0chaindev/sharder:sprint-1.10.1"' ./docker.local/build.sharder/p0docker-compose.yaml
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Starting sharders
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT}/sharder/ssd/docker.local > /dev/null;  #/sharder/ssd
    for i in $(seq 1 $SHARDER)
    do
        cd sharder${i}
        sudo bash ../bin/start.p0sharder.sh ${PROJECT_ROOT}/sharder/ssd ${PROJECT_ROOT}/sharder/hdd
        cd ../
    done
popd > /dev/null;
