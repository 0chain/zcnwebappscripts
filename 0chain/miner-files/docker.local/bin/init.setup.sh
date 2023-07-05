#!/bin/sh

SSD_PATH="${1:-..}"
HDD_PATH="${2:-..}"

for i in $(seq 1 $3)
do
  mkdir -p $SSD_PATH/docker.local/miner"$i"
  mkdir -p $SSD_PATH/docker.local/miner"$i"/data/redis/state
  mkdir -p $SSD_PATH/docker.local/miner"$i"/data/redis/transactions
  mkdir -p $SSD_PATH/docker.local/miner"$i"/data/rocksdb
  mkdir -p $SSD_PATH/docker.local/miner"$i"/log
done