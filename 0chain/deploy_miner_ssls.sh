#!/bin/bash

set -e

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Setup variables
===============================================================================================================================================================================  \e[39m"
export PROJECT_ROOT=/var/0chain # /var/0chain
export BLOCK_WORKER_URL=beta.zus.network
echo -e "\e[32m Successfully Created \e[23m \e[0;37m"

sudo mkdir -p $PROJECT_ROOT

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Checking Miner counts.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    #Miner
    if [[ -f miner/numminers.txt ]] ; then
        echo "Checking for miners."
        MINER=$(cat miner/numminers.txt)
    fi
    #Email
    echo "Checking for email."
    if [[ -f miner/email.txt ]] ; then
        EMAIL=$(cat miner/email.txt)
    fi
    #Checking Miner var's
    if [[ -z ${MINER} ]] ; then
        echo "No Miner exist."
        exit 1
    fi
    #Checking for hosts
    echo "Checking for email."
    if [[ -f miner/url.txt ]] ; then
        HOST=$(cat miner/url.txt)
    fi
    echo -e "\e[32m Counts exists \e[23m \e[0;37m"
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Extract monitoring files
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    curl -L "https://github.com/0chain/zcnwebappscripts/raw/as-deploy/0chain/artifacts/grafana-portainer.zip" -o /tmp/grafana-portainer.zip
    sudo unzip -o /tmp/grafana-portainer.zip -d ${PROJECT_ROOT}
    sudo rm /tmp/grafana-portainer.zip
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Creating promtail configs.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
# Promtail config for miner
    for j in $(seq 1 $MINER); do
cat <<EOF >>${PROJECT_ROOT}/grafana-portainer/promtail/promtail-config.yaml
- job_name: miner${j}
  static_configs:
    - targets:
        - localhost
      labels:
        app: miner-${j}
        __path__: /var/log/miner${j}/log/0chain.log
    - targets:
        - localhost
      labels:
        app: n2n-miner-${j}
        __path__: /var/log/miner${j}/log/n2n.log
EOF
    done
echo -e "\e[32m Successfully Created \e[23m \e[0;37m"
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Creating caddy configs.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;

### Caddyfile
echo "creating Caddyfile"
cat <<EOF >${PROJECT_ROOT}/grafana-portainer/caddy/Caddyfile
(cors) {
  @cors_preflight method OPTIONS
  @cors header Origin {args.0}

  handle @cors_preflight {
    header Access-Control-Allow-Origin "*"
    header Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE"
    header Access-Control-Allow-Headers "*"
    header Access-Control-Max-Age "3600"
    respond "" 204
  }

  handle @cors {
    header Access-Control-Allow-Origin "*"
    header Access-Control-Expose-Headers "Link"
  }
}

${HOST} {
  import cors https://${HOST}
  log {
    output file /var/log/access.log {
      roll_size 1gb
      roll_keep 5
      roll_keep_for 720h
    }
  }
  route {
    redir https://${BLOCK_WORKER_URL}
  }

EOF

for i in $(seq 1 ${MINER}); do
cat <<EOF >>${PROJECT_ROOT}/grafana-portainer/caddy/Caddyfile
  route /miner0${i}* {
    uri strip_prefix /miner0${i}
    reverse_proxy miner-${i}:707${i}
  }

EOF
done

cat <<EOF >>${PROJECT_ROOT}/grafana-portainer/caddy/Caddyfile
  route /portainer* {
    uri strip_prefix /portainer
    header Access-Control-Allow-Methods "POST,PATCH,PUT,DELETE, GET, OPTIONS"
    header Access-Control-Allow-Headers "*"
    header Access-Control-Allow-Origin "*"
    header Cache-Control max-age=3600
    reverse_proxy portainer:9000
  }

  route /grafana* {
    uri strip_prefix /grafana
    reverse_proxy grafana:3000
  }
}
EOF

echo -e "\e[32m Successfully Created \e[23m \e[0;37m"
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Generate random password for grafana and portainer
===============================================================================================================================================================================  \e[39m"
mkdir -p ${PROJECT_ROOT}/grafana-portainer/portainer || true
pushd ${PROJECT_ROOT}/grafana-portainer/portainer > /dev/null;
    if [[ -f portainer_password ]] ; then
      PASSWORD=$(cat portainer_password)
    else
      tr -dc A-Za-z0-9 </dev/urandom | head -c 13 > portainer_password
      PASSWORD=$(cat portainer_password)
    fi
echo -e "\e[32m Successfully Created \e[23m \e[0;37m"
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Deploying grafana and portainer
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT}/grafana-portainer > /dev/null;  #/miner/ssd
    bash ./start.p0monitor.sh ${HOST} admin ${PASSWORD}
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                  Enabling firewall
===============================================================================================================================================================================  \e[39m"
sudo ufw allow 22,80,443,7071,53/tcp
sudo ufw allow out to any port 80
sudo ufw allow out to any port 443
sudo ufw allow out to any port 7071
sudo ufw allow out to any port 53
yes y | sudo ufw enable

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Adding Grafana Dashboards
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT}/grafana-portainer/grafana > /dev/null;

  sed -i "s/hostname/${HOST}/g" ./homepage_miner.json
  sleep 20s

  curl -X POST -H "Content-Type: application/json" \
       -d "@./server.json" \
      "https://admin:${PASSWORD}@${HOST}/grafana/api/dashboards/import"

  # curl -X POST -H "Content-Type: application/json" \
  #      -d "@./docker_system_monitoring.json" \
  #     "https://admin:${PASSWORD}@${HOST}/grafana/api/dashboards/import"

  if [[ ${MINER} -gt 0 ]] ; then
      curl -X POST -H "Content-Type: application/json" \
        -d "{\"dashboard\":$(cat ./homepage_miner.json)}" \
        "https://admin:${PASSWORD}@${HOST}/grafana/api/dashboards/import"

      curl -X PUT -H "Content-Type: application/json" \
        -d '{ "theme": "", "homeDashboardUID": "homepage_miner", "timezone": "utc" }' \
        "https://admin:${PASSWORD}@${HOST}/grafana/api/org/preferences"

      curl -X POST -H "Content-Type: application/json" \
        -d "@./miner.json" \
        "https://admin:${PASSWORD}@${HOST}/grafana/api/dashboards/import"
  fi

popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Grafana and Portainer Credentials
===============================================================================================================================================================================  \e[39m"
echo "Grafana Username --> admin"
echo "Grafana Password --> ${PASSWORD}"
echo -e "\nPortainer Username --> admin"
echo "Portainer Password --> ${PASSWORD}"
