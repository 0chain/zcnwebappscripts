#!/bin/bash
cd ~
cd /var/lib/docker/overlay2/
con_id=$(du -sh ./* | grep "G" | awk '{print $2}')
con_id="${con_id:2}"
echo $con_id
cd /var/lib/docker/overlay2/$con_id/diff/tmp/loki/chunks
if [ $? -ne 0 ]; then
    echo -e "\n\e[93m==== Script failed on diff =====\e[39m"
    exit 1
else
    find . -print0 | xargs -0 rm
fi
pwd
cd /var/lib/docker/overlay2/$con_id/merged/tmp/loki/chunks
if [ $? -ne 0 ]; then
    echo -e "\n\e[93m==== Script failed on merge  =====\e[39m"
    exit 1
else
    find . -print0 | xargs -0 rm
fi
pwd

docker stop loki
docker start loki
