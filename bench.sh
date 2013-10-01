#!/bin/bash

FS='xfs'
STRIPE_UNIT=512
STRIPE_WIDTH=1

# Do not modify anything below this comment

if [ $# >= 0 ]; then
  echo "Usage:"
  echo "cephstore-bench.sh /dev/sdb [/dev/sdc /dev/sdd]"
  exit 1
fi

DEVICES=$@

echo " + Install packages for test prep and benchmarks"
apt-get install -y --force-yes cryptsetup fio parted xfsprogs collectl

for device in ${DEVICES}
do
  if [ -b ${device} ]; then
    echo " + Disable disk cache on ${device}"
    hdparm -W0 ${device}
    echo " + Create disk partitions"
    parted -- ${device} unit MB mkpart primary 1 2048
    parted -- ${device} unit MB mkpart primary 2048 -0
    case FS in
    'xfs')
      echo " + Creating XFS filesystem on data partition"
      mkfs.xfs -d su=${STRIPE_UNIT},sw=${STRIPE_WIDTH} -i size=2048 ${device}2
    esac
    device_basename=$(basename ${device})
    echo " + Mount data partition"
    mkdir -p /mnt/${device_basename}2
    mount ${device}2 /mnt/${device_basename}2

    # Setup collectl

    echo " + FSync and drop linux page cache"
    sync && echo 3 > /proc/sys/vm/drop_caches
    echo " -> Running 4MB random write benchmark (max rados object size)"
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

    echo " + FSync and drop linux page cache"
    sync && echo 3 > /proc/sys/vm/drop_caches
    echo " -> Running 4KB random write benchmark (small IO)"
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

    echo " + FSync and drop linux page cache"
    sync && echo 3 > /proc/sys/vm/drop_caches
    echo " -> Running 8KB random write benchmark (InnoDB IO)"
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

    echo "OpenSSL AES CBC benchmarks"
    openssl speed aes-128-cbc aes-192-cbc aes-256-cbc

  else
    echo "$device is not a block device!"
    exit 1
  fi
done
