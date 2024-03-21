#!/bin/bash

set -e

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        setup variables
===============================================================================================================================================================================  \e[39m"
export PROJECT_ROOT=/var/0chain # /var/0chain
echo -e "\e[32m Successfully set \e[23m \e[0;37m"

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        updating -loki logs cleanup on both sharder and miner.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    if [[ -f loki-logs-cleanup-job.sh ]] ; then
        echo -e "\e[32m loki-logs-cleanup-job.sh file is present \e[23m \e[0;37m"
        sudo rm loki-logs-cleanup-job.sh
        wget -N https://raw.githubusercontent.com/0chain/zcnwebappscripts/as-deploy/0chain/loki-logs-cleanup-job.sh
        sudo chmod +x loki-logs-cleanup-job.sh
    else
        echo -e "\e[31m loki-logs-cleanup-job.sh file is not present. Please contact zus team \e[13m \e[0;37m"
        exit 1
    fi
popd > /dev/null;
