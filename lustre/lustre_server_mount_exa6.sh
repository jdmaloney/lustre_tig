#!/bin/bash

tfile=$(mktemp /tmp/esmount.XXXXXX)
tfile2=$(mktemp /tmp/esmount2.XXXXXX)

source /etc/telegraf/lustre/lustre_config

sudo /usr/bin/es_mount --status --all | grep "/dev/" | cut -d'|' -f 2,4 | sed 's/t\ m/t_m/' | sed 's/\ |\ /\ /' > "${tfile}"
sudo /usr/bin/es_mount --status | grep "/dev/" | cut -d'|' -f 2,4 | sed 's/t\ m/t_m/' | sed 's/\ |\ /\ /' | grep -v mgs > "${tfile2}"

while IFS= read -r line; do
        IFS=" " read -r name mount_state <<< "$(echo ${line})"
	disk_type=$(echo ${name} | cut -c 1-3)
	if [ ${mount_state} == "Mounted" ]; then
		mount_health=1
	else
		mount_health=0
	fi
	optimal=$(grep "${name}" "${tfile2}" | awk '{print $2}')
	if [ -n "${optimal}" ] && [ "${name}" != "mgs" ] && [ ${mount_health} -eq 1 ]; then
		if [ "${optimal}" == "Mounted" ]; then
			echo "es_mount,disk_type=${disk_type},disk_name=${name},fs="${fs}" mount_state=\"${mount_state}\",mount_health=${mount_health},optimal_mount=1"
		else
			echo "es_mount,disk_type=${disk_type},disk_name=${name},fs="${fs}" mount_state=\"${mount_state}\",mount_health=${mount_health},optimal_mount=0"
		fi
	elif [ ${mount_health} -eq 1 ] && [ -z "${optimal}" ] && [ "${name}" != "mgs" ]; then
		echo "es_mount,disk_type=${disk_type},disk_name=${name},fs="${fs}" mount_state=\"${mount_state}\",mount_health=${mount_health},optimal_mount=0"
	else
		echo "es_mount,disk_type=${disk_type},disk_name=${name},fs="${fs}" mount_state=\"${mount_state}\",mount_health=${mount_health}"
	fi
done < "${tfile}"

rm -rf "${tfile}"
rm -rf "${tfile2}"
