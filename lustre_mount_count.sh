#!/bin/bash

## Check if an MDS
mdt_mount=$(grep mdt /proc/mounts | awk '$3 == "lustre" {print $0}')
if [ -n "${mdt_mount}" ]; then

## Get Mount Counts
source /etc/telegraf/lustre/lustre_config

for f in ${filesystems[@]}
do
	mount_count=$(lshowmount -e | wc -l)
	echo "lustre_mount_count,file_system=${f} count=${mount_count}"
done


else
	:
fi
