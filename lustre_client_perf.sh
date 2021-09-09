#!/bin/bash

source /etc/telegraf/lustre/lustre_config

ost_mdt=($(ls /proc/fs/lustre/obdfilter/))

for d in ${ost_mdt[@]}
do
	clients=($(ls /proc/fs/lustre/obdfilter/${d}/exports/ | grep -v clear))
	for c in ${clients[@]}
	do
		ip=$(echo ${c} | cut -d'@' -f 1)
		client_name=$(grep "${ip}" ${map_file} | awk '{print $2}')
		fs=$(echo "${d}" | cut -d'-' -f 1)
		disk_type=$(echo "${d}" | cut -d'-' -f 2 | cut -c 1-3 )
		stats_line=$(grep -v snapshot /proc/fs/lustre/obdfilter/${d}/exports/${c}/stats | awk '{print $1"="$8}' | xargs | sed 's/\ /,/g')
		if [ -n "${stats_line}" ]; then
			echo lustre_client_perf,fs=${fs},disk_type=${disk_type},disk=${d},client=${client_name} ${stats_line}
		fi
	done
done
