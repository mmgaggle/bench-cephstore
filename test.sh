#!/bin/bash

set -o nounset
set -o errexit

DEVICE=$1
DEVICE_BASENAME=$(basename ${DEVICE})
PREFIX=$(date +%d%m%y-%H%M%S)

echo " + Results will be stored at /tmp/${PREFIX}-fio"
mkdir /tmp/${PREFIX}-fio

echo " + Disable disk cache on ${DEVICE}"
hdparm -qW0 ${DEVICE}
echo " + Create disk partitions"
parted --script -- ${DEVICE} mklabel gpt unit MB mkpart primary 1 -0
echo " + Creating XFS filesystem"
mkfs.xfs -qfd su=64k,sw=1 -i size=2048 ${DEVICE}1
echo " + Mount data partition"
mkdir -p /mnt/${DEVICE_BASENAME}1
mount ${DEVICE}1 /mnt/${DEVICE_BASENAME}1

function fio_file {
  # need to test for variables
  DESCRIPTION=$1
  MODE=$2
  IOENGINE=$3
  BLOCK_SIZE=$4
  ITERATIONS=$5

  echo ${DESCRIPTION}
  echo " + FSync and drop linux page cache"
  sync && echo 3 > /proc/sys/vm/drop_caches
  echo " + Begin test"
  fio --directory /mnt/${DEVICE_BASENAME}1
      --name=${DEVICE} \
      --direct=1 \
      --rw=${MODE} \
      --bs=${BLOCK_SIZE} \
      --ioengine=${IOENGINE}\
      --iodepth=16 \
      --numjobs 1 \
      --time_based \
      --runtime 300 \
      --size 1G \
      --group_reporting \
      | tee -a /tmp/${PREFIX}-fio/${ITERATION}/fio-${MODE}-${IOENGINE}-${BLOCK_SIZE}.log
}

# Single DEVICE benchmark
for iteration in $( seq 1 3 );do
  for block_size in 4096 8192 16384 65536 4194304;do
    for mode in 'write' 'read' 'rw' 'randwrite' 'randread' 'randrw';do
       mkdir /tmp/${PREFIX}-fio/${iteration}
      fio_block "Running ${block_size} ${mode} workload against ${DEVICE}" ${mode} "libaio" ${block_size} ${iteration}
    done
  done
done

echo " -> Running OpenSSL AES CBC benchmarks"
openssl speed aes-128-cbc aes-192-cbc aes-256-cbc

umount /mnt/${DEVICE}1
