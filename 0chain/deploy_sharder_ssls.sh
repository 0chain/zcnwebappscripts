#!/bin/bash

set -e

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Setup variables
===============================================================================================================================================================================  \e[39m"
export PROJECT_ROOT=/var/0chain # /var/0chain
export BLOCK_WORKER_URL=mainnet.zus.network
echo -e "\e[32m Successfully Created \e[23m \e[0;37m"

sudo mkdir -p $PROJECT_ROOT

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Checking Sharder counts.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
    #Sharder
    if [[ -f sharder/numsharder.txt ]] ; then
        echo "Checking for Sharders."
        SHARDER=$(cat sharder/numsharder.txt)
    fi
    #Email
    if [[ -f sharder/email.txt ]] ; then
        EMAIL=$(cat sharder/email.txt)
    fi
    #Checking sharder var's
    if [[ -z ${SHARDER} ]] ; then
        echo "No Sharder exist."
        exit 1
    fi
    #Checking for hosts
    echo "Checking for email."
    if [[ -f sharder/url.txt ]] ; then
        HOST=$(cat sharder/url.txt)
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
# Promtail config for sharder
    for i in $(seq 1 $SHARDER); do
cat <<EOF >>${PROJECT_ROOT}/grafana-portainer/promtail/promtail-config.yaml
- job_name: sharder${i}
  static_configs:
    - targets:
        - localhost
      labels:
        app: sharder-${i}
        __path__: /var/log/sharder${i}/log/0chain.log
    - targets:
        - localhost
      labels:
        app: n2n-sharder-${i}
        __path__: /var/log/sharder${i}/log/n2n.log
EOF
    done
echo -e "\e[32m Successfully Created \e[23m \e[0;37m"
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Creating caddy configs.
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT} > /dev/null;
# Promtail config for sharder

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

for i in $(seq 1 ${SHARDER}); do
cat <<EOF >>${PROJECT_ROOT}/grafana-portainer/caddy/Caddyfile
  route /sharder0${i}* {
    uri strip_prefix /sharder0${i}
    reverse_proxy sharder-${i}:717${i}
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
pushd ${PROJECT_ROOT}/grafana-portainer > /dev/null;  #/sharder/ssd
    sudo chown 10001:10001 ./loki
    bash ./start.p0monitor.sh ${HOST} admin ${PASSWORD}
popd > /dev/null;

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                  Enabling firewall
===============================================================================================================================================================================  \e[39m"
sudo ufw allow 22,80,443,53/tcp
sudo ufw allow out to any port 80
sudo ufw allow out to any port 443
sudo ufw allow out to any port 7171
sudo ufw allow out to any port 53
yes y | sudo ufw enable

echo -e "\n\e[93m===============================================================================================================================================================================
                                                                                Adding Grafana Dashboards
===============================================================================================================================================================================  \e[39m"
pushd ${PROJECT_ROOT}/grafana-portainer/grafana > /dev/null;

  sed -i "s/hostname/${HOST}/g" ./homepage_sharder.json
  sleep 20s

  curl -X POST -H "Content-Type: application/json" \
       -d "@./server.json" \
      "https://admin:${PASSWORD}@${HOST}/grafana/api/dashboards/import"

  # curl -X POST -H "Content-Type: application/json" \
  #      -d "@./docker_system_monitoring.json" \
  #     "https://admin:${PASSWORD}@${HOST}/grafana/api/dashboards/import"

  if [[ ${SHARDER} -gt 0 ]] ; then
      curl -X POST -H "Content-Type: application/json" \
        -d "{\"dashboard\":$(cat ./homepage_sharder.json)}" \
        "https://admin:${PASSWORD}@${HOST}/grafana/api/dashboards/import"

      curl -X PUT -H "Content-Type: application/json" \
        -d '{ "theme": "", "homeDashboardUID": "homepage_sharder", "timezone": "utc" }' \
        "https://admin:${PASSWORD}@${HOST}/grafana/api/org/preferences"

    curl -X POST -H "Content-Type: application/json" \
         -d "@./sharder.json" \
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
