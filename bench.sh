#!/bin/bash

if [ $# -le 0 ]; then
  echo "Usage:"
  echo "cephstore-bench.sh /dev/sdb [/dev/sdc /dev/sdd]"
  exit 1
fi

DEVICES=$@

echo "Preparing Machine"
echo " + Update package manifests"
apt-get -q update

echo " + Install packages for test prep and benchmarks"
apt-get install -qy --force-yes cryptsetup fio parted xfsprogs collectl pciutils ethtool ipmitool

for device in ${DEVICES}
do
  if [ -b ${device} ]; then
    echo " + Disable disk cache on ${device}"
    hdparm -qW0 ${device}
    echo " + Create disk partitions"
    parted --script -- ${device} mklabel gpt unit MB mkpart primary 1 2048
    parted --script -- ${device} unit MB mkpart primary 2048 -0
    case ${FS} in
    'xfs')
      echo " + Creating XFS filesystem on data partition"
      mkfs.xfs -qfd su=64k,sw=1 -i size=2048 ${device}2
    esac
    device_basename=$(basename ${device})
    echo " + Mount data partition"
    mkdir -p /mnt/${device_basename}2
    mount ${device}2 /mnt/${device_basename}2
  else
    echo "$device is not a block device!"
    exit 1
  fi
done

# Setup collectl

# Gather Machine Information
# Replace with Ohai?

cat /proc/cpuinfo >> /tmp/bench.log
dmidecode -t 16 >> /tmp/bench.log
dmidecode -t 17 >> /tmp/bench.log
lspci >> /tmp/bench.log

echo "Running 4MB random write benchmark (RADOS max object size)"
echo " + FSync and drop linux page cache"
sync && echo 3 > /proc/sys/vm/drop_caches
echo " + Begin test"
fio --rw=write \
    --ioengine=libaio \
    --iodepth=16 \
    --direct=1 \
    --numjobs 1 \
    --runtime 300 \
    --size 1G \
    --bs=4M \
    --name=${device}1 \
    --name=/mnt/${device_basename}2

echo "Running 4KB random write benchmark (InnoDB 4K pagesize)"
echo " + FSync and drop linux page cache"
sync && echo 3 > /proc/sys/vm/drop_caches
echo " + Begin test"
fio --rw=write \
    --ioengine=libaio \
    --iodepth=16 \
    --direct=1 \
    --numjobs 1 \
    --runtime 300 \
    --size 1G \
    --bs=4K \
    --name=${device}1 \
    --name=/mnt/${device_basename}2

echo "Running 8KB random write benchmark (InnoDB 8K pagesize)"
echo " + FSync and drop linux page cache"
sync && echo 3 > /proc/sys/vm/drop_caches
echo " + Begin test"
fio --rw=write \
    --ioengine=libaio \
    --iodepth=16 \
    --direct=1 \
    --numjobs 1 \
    --runtime 300 \
    --size 1G \
    --bs=8K \
    --name=${device}1 \
    --name=/mnt/${device_basename}2

echo " -> Running OpenSSL AES CBC benchmarks"
openssl speed aes-128-cbc aes-192-cbc aes-256-cbc
