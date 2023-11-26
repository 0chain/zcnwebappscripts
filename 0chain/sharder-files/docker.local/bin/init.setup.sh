#!/bin/sh

SSD_PATH="${1:-..}"
HDD_PATH="${2:-..}"

for i in $(seq 1 $3)
do
  mkdir -p $HDD_PATH/docker.local/sharder"$i"/data/blocks
  mkdir -p $HDD_PATH/docker.local/sharder"$i"/data/rocksdb
  mkdir -p $HDD_PATH/docker.local/sharder"$i"/data/postgresql2
  mkdir -p $HDD_PATH/docker.local/sharder"$i"/log
  mkdir -p $SSD_PATH/docker.local/sharder"$i"/data/postgresql
  chmod 755 -R $SSD_PATH/docker.local/sharder"$i"
done