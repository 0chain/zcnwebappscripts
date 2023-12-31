docker stop loki
rm -rf /var/0chain/grafana-portainer/loki/chunks
docker start loki
