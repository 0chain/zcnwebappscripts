#!/bin/bash

set -e

sed -i "s/10000000000/20000000000000000/g" /var/0chain/initial_states.yaml

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                setup variables 
===============================================================================================================================================================================  \e[39m"
export PROJECT_ROOT=/var/0chain # /var/0chain
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
                                                                            Extract sharder files
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    curl -L "https://github.com/0chain/zcnwebappscripts/raw/as-deploy/0chain/artifacts/sharder-files.zip" -o /tmp/sharder-files.zip
    sudo unzip -o /tmp/sharder-files.zip && rm -rf /tmp/sharder-files.zip
    sudo cp -rf sharder-files/* ${PROJECT_ROOT}/sharder/ssd/
    sudo rm -rf sharder-files
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Copy configs.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    if [[ ${SHARDER} -gt 0 ]] ; then
        echo "Copying sharder keys & configs."
        sudo cp -rf keys/b0s* sharder/ssd/docker.local/config    # sharder/ssd/docker.local/config
        sudo cp -f nodes.yaml sharder/ssd/docker.local/config/nodes.yaml
        sudo cp -f b0magicBlock.json sharder/ssd/docker.local/config/b0magicBlock_4_miners_2_sharders.json
        sudo cp -f initial_states.yaml sharder/ssd/docker.local/config/initial_state.yaml
    fi
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                        Executing sharder scripts
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT}/sharder/ssd > /dev/null;  #/sharder/ssd
    if [[ ${SHARDER} -gt 0 ]]; then
        sudo bash docker.local/bin/init.setup.sh ${PROJECT_ROOT}/sharder/ssd ${PROJECT_ROOT}/sharder/hdd $SHARDER
        sudo bash docker.local/bin/setup.network.sh || true
    fi
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Generate random password & updating for sharder postgres
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT}/sharder/ssd > /dev/null;
    if [[ -f sharder_pg_password ]] ; then
      PG_PASSWORD=$(cat sharder_pg_password)
    else
      tr -dc A-Za-z0-9 </dev/urandom | head -c 13 > sharder_pg_password
      PG_PASSWORD=$(cat sharder_pg_password)
    fi
    echo -e "\e[32m Successfully Created \e[23m \e[0;37m"
    # sed -i "s/zchian/${PG_PASSWORD}/g" ./docker.local/config/0chain.yaml
    sed -i "s/zchian/${PG_PASSWORD}/g" ./docker.local/sql_script/00-create-user.sql
    sed -i "s/zchian/${PG_PASSWORD}/g" ./docker.local/build.sharder/p0docker-compose.yaml
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
