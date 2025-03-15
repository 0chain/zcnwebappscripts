#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
  echo "This script requires sudo privileges. Please enter your password:"
  exec sudo "$0" "$@" # This re-executes the script with sudo
fi

# setup variables
export DEBIAN_FRONTEND=noninteractive

export PROJECT_ROOT_SSD=/var/0chain/blobber/ssd
export PROJECT_ROOT_HDD=/var/0chain/blobber/hdd

export BRANCH_NAME=main

#Setting latest docker image wrt latest release
export DOCKER_IMAGE=$(curl -s https://registry.hub.docker.com/v2/repositories/0chaindev/blobber/tags?page_size=100 | jq -r '.results[] | select(.name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | .name' | sort -V | tail -n 1)
export DOCKER_IMAGE_EBLOBBER=$(curl -s https://registry.hub.docker.com/v2/repositories/0chaindev/eblobber/tags?page_size=100 | jq -r '.results[] | select(.name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | .name' | sort -V | tail -n 1)

### docker-compose.yaml
echo "creating docker-compose file"
cat <<EOF >${PROJECT_ROOT}/docker-compose.yml
---
version: "3"
services:
  postgres:
    image: postgres:14
    environment:
      POSTGRES_HOST_AUTH_METHOD: trust
      POSTGRES_USER: blobber_user
      POSTGRES_DB: blobber_meta
      POSTGRES_PASSWORD: blobber
      SLOW_TABLESPACE_PATH: /var/lib/postgresql/hdd
      SLOW_TABLESPACE: hdd_tablespace
    volumes:
      - ${PROJECT_ROOT_SSD}/data/postgresql:/var/lib/postgresql/data
      - ${PROJECT_ROOT_HDD}/pg_hdd_data:/var/lib/postgresql/hdd
      - ${PROJECT_ROOT}/postgresql.conf:/var/lib/postgresql/postgresql.conf
      - ${PROJECT_ROOT}/sql_init:/docker-entrypoint-initdb.d
    command: postgres -c config_file=/var/lib/postgresql/postgresql.conf
    networks:
      default:
    restart: "always"

  validator:
    image: 0chaindev/validator:${DOCKER_IMAGE}
    environment:
      - DOCKER= true
    volumes:
      - ${PROJECT_ROOT}/config:/validator/config
      - ${PROJECT_ROOT_HDD}/data:/validator/data
      - ${PROJECT_ROOT_HDD}/log:/validator/log
      - ${PROJECT_ROOT}/keys_config:/validator/keysconfig
    command: ./bin/validator --port 5061 --hostname ${BLOBBER_HOST} --deployment_mode 0 --keys_file keysconfig/b0vnode01_keys.txt --log_dir /validator/log --hosturl https://${BLOBBER_HOST}/validator
    networks:
      default:
    restart: "always"

  blobber:
    image: 0chaindev/blobber:${DOCKER_IMAGE}
    environment:
      DOCKER: "true"
      DB_NAME: blobber_meta
      DB_USER: blobber_user
      DB_PASSWORD: blobber
      DB_PORT: "5432"
      DB_HOST: postgres
    depends_on:
      - validator
    links:
      - validator:validator
    volumes:
      - ${PROJECT_ROOT}/config:/blobber/config
      - ${PROJECT_ROOT_HDD}/files:/blobber/files
      - ${PROJECT_ROOT_HDD}/data:/blobber/data
      - ${PROJECT_ROOT_HDD}/log:/blobber/log
      - ${PROJECT_ROOT_SSD}/data/pebble/data:/pebble/data
      - ${PROJECT_ROOT_SSD}/data/pebble/wal:/pebble/wal
      - ${PROJECT_ROOT}/keys_config:/blobber/keysconfig # keys and minio config
      - ${PROJECT_ROOT_HDD}/data/tmp:/tmp
      - ${PROJECT_ROOT}/sql:/blobber/sql
    command: ./bin/blobber --port 5051 --grpc_port 31501 --hostname ${BLOBBER_HOST} --deployment_mode 0 --keys_file keysconfig/b0bnode01_keys.txt --files_dir /blobber/files --log_dir /blobber/log --db_dir /blobber/data --hosturl https://${BLOBBER_HOST}
    networks:
      default:
    restart: "always"

  caddy:
    image: caddy:2.6.4
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ${PROJECT_ROOT}/Caddyfile:/etc/caddy/Caddyfile
      - ${PROJECT_ROOT}/site:/srv
      - ${PROJECT_ROOT}/caddy_data:/data
      - ${PROJECT_ROOT}/caddy_config:/config
    restart: "always"

  promtail:
    image: grafana/promtail:2.8.2
    volumes:
      - ${PROJECT_ROOT_HDD}/log/:/logs
      - ${PROJECT_ROOT}/monitoringconfig/promtail-config.yaml:/mnt/config/promtail-config.yaml
    command: -config.file=/mnt/config/promtail-config.yaml
    restart: "always"

  loki:
    image: grafana/loki:2.8.2
    user: "1001"
    volumes:
      - ${PROJECT_ROOT}/monitoringconfig/loki-config.yaml:/mnt/config/loki-config.yaml
      - ${PROJECT_ROOT_HDD}/loki:/data
      - ${PROJECT_ROOT_HDD}/loki/rules:/etc/loki/rules
    command: -config.file=/mnt/config/loki-config.yaml
    restart: "always"

  prometheus:
    image: prom/prometheus:v2.44.0
    user: root
    volumes:
      - ${PROJECT_ROOT}/monitoringconfig/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    restart: "always"
    depends_on:
    - cadvisor

  cadvisor:
    image: wywywywy/docker_stats_exporter:20220516
    container_name: cadvisor
    volumes:
    - /var/run/docker.sock:/var/run/docker.sock
    restart: "always"

  node-exporter:
    image: prom/node-exporter:v1.5.0
    container_name: node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)(\$\$|/)'
    restart: "always"

  grafana:
    image: grafana/grafana:9.5.2
    environment:
      GF_SERVER_ROOT_URL: "https://${BLOBBER_HOST}/grafana"
      GF_SECURITY_ADMIN_USER: "${GF_ADMIN_USER}"
      GF_SECURITY_ADMIN_PASSWORD: "${GF_ADMIN_PASSWORD}"
      GF_AUTH_ANONYMOUS_ENABLED: "true"
      GF_AUTH_ANONYMOUS_ORG_ROLE: "Viewer"
    volumes:
      - ${PROJECT_ROOT}/monitoringconfig/datasource.yml:/etc/grafana/provisioning/datasources/datasource.yaml
      - grafana_data:/var/lib/grafana
    restart: "always"

  monitoringapi:
    image: 0chaindev/monitoringapi:latest
    restart: "always"

  agent:
    image: portainer/agent:2.18.2-alpine
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes

  portainer:
    image: portainer/portainer-ce:2.18.2-alpine
    command: '-H tcp://agent:9001 --tlsskipverify --admin-password-file /tmp/portainer_password'
    depends_on:
      - agent
    links:
      - agent:agent
    volumes:
      - portainer_data:/data
      - /tmp/portainer_password:/tmp/portainer_password
    restart: "always"

networks:
  default:
    driver: bridge

volumes:
  grafana_data:
  prometheus_data:
  portainer_data:

EOF

/usr/local/bin/docker-compose -f ${PROJECT_ROOT}/docker-compose.yml down
/usr/local/bin/docker-compose -f ${PROJECT_ROOT}/docker-compose.yml pull
/usr/local/bin/docker-compose -f ${PROJECT_ROOT}/docker-compose.yml up -d

echo "Blobber KMS mode is disabled."
