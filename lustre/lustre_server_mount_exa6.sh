#!/bin/bash

tfile=$(mktemp /tmp/esmount.XXXXXX)

sudo /usr/bin/es_mount --status --all | grep "/dev/" | cut -d'|' -f 2,4 | sed 's/t\ m/t_m/' | sed 's/\ |\ /\ /' > "${tfile}"

while IFS= read -r line; do
        IFS=" " read -r name mount_state <<< "$(echo ${line})"
	if [ ${mount_state} == "Mounted" ]; then
		mount_health=1
	else
		mount_health=0
	fi
	disk_type=$(echo ${name} | cut -c 1-3)
        echo "es_mount,disk_type=${disk_type},disk_name=${name} mount_state=\"${mount_state}\",mount_health=${mount_health}"
done < "${tfile}"

rm -rf "${tfile}"
