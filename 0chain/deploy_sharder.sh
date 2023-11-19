#!/bin/bash

set -e
sed -i "s/f1d14699ccad97ca893a635e68e128b0717f8a1aab1a071db6b40935cbfce90c/53b4a4d0589073953b130f0c8e2442604eafe5dea35b84675b28a4130dd6393e/g" /var/0chain/initial_states.yaml
sed -i "s/7051ca0cf6f6157a54fa91570d2bb8ab8723b1050381b3d95b66debfdbcf5416/44b67a3967cf3b03c8c1a78aba68792b4b1cb4eb2c4c2e7f70e82cdac839b94f/g" /var/0chain/initial_states.yaml
sed -i "s/4de1553b44e4942593b96ca2ee86d543967762929bf6db9c7c65a7446984e6f1/939ffc27003e9bb9245919b1241c04736f931bfc1ee972dd68df5f602412298e/g" /var/0chain/initial_states.yaml
sed -i "s/c7cd30d15f713068e65c6469df38d84ec128267bba2c4067360b4d69f208c75e/44f05cf93613e3e4a81fd302cfb8a02b659805a35e137517dcd7842734151130/g" /var/0chain/initial_states.yaml
sed -i "s/37567fc630d9b747364678158df4fcae8d5da2c077681a592ff406c143b5c664/13590e0a424f18e69ae02340b709224e1a35efce055075aa732355d84b24ad3f/g" /var/0chain/initial_states.yaml
sed -i "s/ee1a04d880f03c8f9df25f825a27526a34626dcf9bcffd5c7c182919315e899e/917eff333fce4ec28a7cb17766444647856dc9510a24a023ac1c77285f192d36/g" /var/0chain/initial_states.yaml
sed -i "s/07aebb92690d3946e5f66b8088ca1fd5e8049dbf203167fc000e22a0a9ea9071/e1d4e71b78183ff84705c8d02168e32e8a76ec640728c818a57a657e3193a4db/g" /var/0chain/initial_states.yaml
sed -i "s/14b16712cc0d3d2573299a474c0e297616aaea2413709fa8d3d6fda698609142/98263b134301754f22a6e4fc187d1cd47bf7283f1eac89674de727b702733fad/g" /var/0chain/initial_states.yaml
sed -i "s/5d6bb641dac8fd6d78efe64436ec4b096e2c67ba43386084fe7bce48389a8394/cca8ce335e165935eb546e3631712e68413f5c23910f0941e58c889b1fc67bd5/g" /var/0chain/initial_states.yaml
sed -i "s/120501bbbf5f1cbcfb939952e37ef7ff85bf0282031e2ec81edaa5f424242ae8/c0f8a22fcb41309d8927c46d471ef4989bde6ac1c72ac15858daae2bc4213236/g" /var/0chain/initial_states.yaml
sed -i "s/1746b06bb09f55ee01b33b5e2e055d6cc7a900cb57c0a3a5eaabb8a0e7745802/20000000000000000/g" /var/0chain/initial_states.yaml
sed -i "s/65b32a635cffb6b6f3c73f09da617c29569a5f690662b5be57ed0d994f234335/20000000000000000/g" /var/0chain/initial_states.yaml

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                Installing yq on your server
===============================================================================================================================================================================  \e[39m"
echo -e "\e[32m 1. Setting up yaml query. \e[23m \e[0;37m"
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 || true
sudo chmod a+x /usr/local/bin/yq || true
yq --version || true

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

    #Sharder Delegate wallet
    if [[ -f del_wal_id.txt ]] ; then
        echo -e "\e[32m Sharders delegate wallet id present \e[23m \e[0;37m"
        SHARDER_DEL=$(cat del_wal_id.txt)
    else
        echo "Unable to find sharder delegate wallet"
        exit 1
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
        sudo cp -f b0magicBlock.json sharder/ssd/docker.local/config/b0magicBlock.json
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
    echo -e "\e[32m Successfully Created the password\e[23m \e[0;37m"
    yq e -i '.delegate_wallet = "${SHARDER_DEL}"' ./docker.local/config/0chain.yaml
    sed -i "s/zchian/${PG_PASSWORD}/g" ./docker.local/sql_script/00-create-user.sql
    sed -i "s/zchian/${PG_PASSWORD}/g" ./docker.local/build.sharder/p0docker-compose.yaml
    echo -e "\e[32m Successfully Updated the configs\e[23m \e[0;37m"
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Tablespace permission to sharder postgres
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT}/sharder/hdd/docker.local > /dev/null;
    for i in $(seq 1 $SHARDER)
    do
        cd sharder${i}/data/
        chown -R 999:999 postgresql2
        cd ../../
    done
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
