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
apt-get install -qy --force-yes cryptsetup fio parted xfsprogs collectl pciutils ethtool ipmitool dmidecode

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

cat /proc/cpuinfo >> /tmp/bench-system-info.log
dmidecode -t 16 >> /tmp/bench-system-info.log
dmidecode -t 17 >> /tmp/bench-system-info.log
lspci >> /tmp/bench.log

function flexible_io_test {
  description=$1
  rw=$2
  ioengine=$3
  block_size=$4
  
  echo ${description}
  echo " + FSync and drop linux page cache"
  sync && echo 3 > /proc/sys/vm/drop_caches
  echo " + Begin test"
  echo fio --rw=${rw} \
      --ioengine=${ioengine}\
      --iodepth=16 \
      --direct=1 \
      --numjobs 1 \
      --runtime 300 \
      --size 1G \
      --bs=${block_size} \
      --name=${device}1 \
      --name=/mnt/${device_basename}2 | tee -a /tmp/bench-fio-${rw}-${ioengine}-${block_size}
}

flexible_io_test("Running 4MB random write benchmark (RADOS max object size)","write","libaio","4M")
flexible_io_test("Running 4KB random write benchmark (InnoDB 4K pagesize)","write","libaio","4K")
flexible_io_test("Running 8KB random write benchmark (InnoDB 4K pagesize)","write","libaio","8K")

flexible_io_test("Running 4MB sync write benchmark", "write","sync","4M")
flexible_io_test("Running 4KB sync write benchmark", "write","sync","4K")
flexible_io_test("Running 8KB sync benchmark","write","sync","8K")

echo " -> Running OpenSSL AES CBC benchmarks"
openssl speed aes-128-cbc aes-192-cbc aes-256-cbc
