#!/bin/bash

source /etc/telegraf/lustre/lustre_config

## If the map file doesn't exist/is empty or at 15 past the hour update the map file of clients
if [ $(date +%M) == "15" ] || [ ! -f ${map_file} ] || [ $(wc -l ${map_file} | cut -d' ' -f 1) -eq 0 ]; then	
	test_host=$(nslookup "${test_ip}" | cut -d' ' -f 3 | rev | cut -c 2- | rev)
	if [ "${test_host}" != "${test_hostname}" ]; then
		## DNS lookup failed; aborting map update this hour
		:
	else
		rm -rf ${map_file}
		ips=($(ls /proc/fs/lustre/obdfilter/taiga-*/exports/ | grep "@" | grep -v "@lo" | sort -u | cut -d'@' -f 1 | xargs))
		for i in ${ips[@]}
		do
			echo ${i}" "$(nslookup ${i} | cut -d' ' -f 3 | rev | cut -c 2- | rev) >> ${map_file}
		done
	fi
fi

ost_mdt=($(ls /proc/fs/lustre/obdfilter/))

for d in ${ost_mdt[@]}
do
	clients=($(ls /proc/fs/lustre/obdfilter/${d}/exports/ | grep "@" | grep -v "@lo"))
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
