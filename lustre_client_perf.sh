#!/bin/bash

source /etc/telegraf/lustre/lustre_config

## If the map file doesn't exist/is empty or at 15 past the hour update the map file of clients
if [ $(date +%M) == "15" ] || [ ! -f ${map_file} ] || [ $(wc -l ${map_file} | cut -d' ' -f 1) -eq 0 ]; then	
	test_host=$(nslookup "${test_ip}" | cut -d' ' -f 3 | rev | cut -c 2- | rev)
	if [ "${test_host}" != "${test_hostname}" ]; then
		# DNS lookup failed; aborting map update this hour
		:
	else
		rm -rf ${map_file}
		ips=($(ls /proc/fs/lustre/obdfilter/taiga-*/exports/ | grep "@" | grep -v "@lo" | sort -u | cut -d'@' -f 1 | xargs))
		for i in ${ips[@]}
		do
			hostname=$(nslookup ${i} | cut -d' ' -f 3 | rev | cut -c 2- | rev)
			if [ ${hostname} != "can'" ]; then
				echo "${i}" "${hostname}" >> ${map_file}
			fi
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
		client_name=$(awk -v ip="${ip}" '$1 == ip {print $2}' ${map_file})
		if [ "${client_name}" != "" ]; then
			fs=$(echo "${d}" | cut -d'-' -f 1)
			disk_type=$(echo "${d}" | cut -d'-' -f 2 | cut -c 1-3 )
			stats_line=$(grep -v snapshot /proc/fs/lustre/obdfilter/${d}/exports/${c}/stats | awk '{print $1"="$7}' | xargs | sed 's/\ /,/g' | sed 's/=$/=0/' | sed 's/=,/=0/g')
			if [ -n "${stats_line}" ]; then
				echo lustre_client_perf,fs=${fs},disk_type=${disk_type},disk=${d},client=${client_name} ${stats_line}
			fi
		fi
	done
done
