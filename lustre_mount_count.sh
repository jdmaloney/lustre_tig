#!/bin/bash

source /etc/telegraf/lustre_config

## Get Mount Counts
for f in ${filesystems[@]}
do
	mount_count=$(lshowmount -e | wc -l)
	echo "lustre_mount_count,file_system=${f} count=${mount_count}"
done
