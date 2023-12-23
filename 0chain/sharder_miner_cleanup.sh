#!/bin/bash

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                setup variables
===============================================================================================================================================================================  \e[39m"
export PROJECT_ROOT=/var/0chain # /var/0chain
echo -e "\e[32m Successfully Created \e[23m \e[0;37m"

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        cleaning up sharder/miner.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    docker rm -f $(docker ps -a -q)
    rm -rf /var/0chain/miner/ssd/* || true
    rm -rf /var/0chain/miner/hdd/* || true
    rm -rf /var/0chain/grafana-portainer/* || true
    rm -rf /var/0chain/sharder/ssd/* || true
    rm -rf /var/0chain/sharder/hdd/* || true
    rm -rf /var/0chain/*.zip || true
    rm -rf /var/0chain/initial_states.yaml || true
    echo 'y' | docker system prune -a || true
    echo 'y' | docker volume prune -a || true
popd > /dev/null;
