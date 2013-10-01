#!/bin/bash

if [ $# >= 0 ]; then
  echo "Usage:"
  echo "cephstore-bench.sh /dev/sdb [/dev/sdc /dev/sdd]"
  exit 1
fi

DEVICES=$@

FS='xfs'
STRIPE_UNIT=512
STRIPE_WIDTH=1

echo " + Install packages for test prep and benchmarks"
apt-get install -y --force-yes dmcrypt fio parted xfsprogs

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
	echo " + Mount data partition"
	mkdir -p /mnt/${device}2
	mount ${device}2 /mnt/${device}2
	echo " + Sync system"
	sync
	echo " + Drop linux page cache"
	echo 3 > /proc/sys/vm/drop_caches

  else
    echo "$device is not a block device!"
    exit 1
  fi
done
