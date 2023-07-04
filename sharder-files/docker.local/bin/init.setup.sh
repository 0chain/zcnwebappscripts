#!/bin/sh

SSD_PATH="${1:-..}"
HDD_PATH="${2:-..}"

for i in $(seq 1 $3)
do
  mkdir -p $SSD_PATH/docker.local/sharder"$i"/data/blocks
  mkdir -p $SSD_PATH/docker.local/sharder"$i"/data/rocksdb
  mkdir -p $SSD_PATH/docker.local/sharder"$i"/log
  mkdir -p $HDD_PATH/docker.local/sharder"$i"/data/postgresql
done