#!/bin/bash

set -o nounset
set -o errexit

PREFIX=$(date +%d%m%y-%H%M)

mkdir /tmp/${PREFIX}-fio

function fio_block {
  # need to test for variables
  description=$1
  rw=$2
  ioengine=$3
  block_size=$4
  iteration=$5

  mkdir /tmp/${PREFIX}/${iteration}
  
  echo ${description}
  echo " + FSync and drop linux page cache"
  sync && echo 3 > /proc/sys/vm/drop_caches
  echo " + Begin test"
  fio --rw=${rw} \
      --ioengine=${ioengine}\
      --iodepth=16 \
      --direct=1 \
      --numjobs 1 \
      --ramptime 60 \
      --runtime 300 \
      --size 1G \
      --bs=${block_size} \
      --name=${device}1 \
      | tee -a /tmp/${PREFIX}-fio/${iteration}/fio-${rw}-${ioengine}-${block_size}.log
}

# Single device benchmark
for iteration in $( seq 1 3 );do
  for block_size in 4096 8192 16384 65536 4194304;do
    for mode in 'write' 'read' 'rw' 'randwrite' 'randread' 'randrw';do
      fio_block "Running ${block_size} ${rw} workload against ${device}" ${mode} "libaio" ${block_size} ${iteration}
    done
  done
done

echo " -> Running OpenSSL AES CBC benchmarks"
openssl speed aes-128-cbc aes-192-cbc aes-256-cbc
