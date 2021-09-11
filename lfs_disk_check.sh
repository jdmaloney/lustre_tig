#!/bin/bash

tfile=$(mktemp /tmp/lfs_df.XXXXXX)

lfs df | tail -n +2 | grep "UUID" > ${tfile}


while IFS= read -r line; do
        IFS=" " read -r name size_kb used_kb used_p path <<< "$(echo ${line} | awk '{print $1" "$2" "$3" "$5" "$6}')"
	id=$(echo ${path} | cut -d'[' -f 2 | cut -d']' -f 1)
	disk_type=$(echo ${id} | cut -d':' -f 1)
	used_percent=$(echo ${used_p} | cut -d'%' -f 1)
        echo "lfs_df,disk_type=${disk_type},disk_id=${id},name=${name} used_kb=${used_kb},size_kb=${size_kb},used_percent=${used_percent}"
done < "${tfile}"

lfs mdts | tail -n +2 > ${tfile}

while IFS= read -r line; do
	id=$(echo ${line} | cut -d':' -f 1)
	name=$(echo ${line} | cut -d' ' -f 2)
	text_state=$(echo ${line} | cut -d' ' -f 3)
	if [ ${text_state} == "ACTIVE" ]; then
		health_state=0
	else
		health_state=1
	fi
	fs=$(echo ${name} | cut -d'-' -f 1)
        echo "lustre_disk_health,disk_type=mdt,fs=${fs},disk_id=${id},name=${name} health_state=${health_state},text_state=\"${text_state}\""
done < "${tfile}"


lfs osts | tail -n +2 > ${tfile}


while IFS= read -r line; do
        id=$(echo ${line} | cut -d':' -f 1)
        name=$(echo ${line} | cut -d' ' -f 2)
        text_state=$(echo ${line} | cut -d' ' -f 3)
        if [ ${text_state} == "ACTIVE" ]; then
                health_state=0
        else
                health_state=1
        fi
	fs=$(echo ${name} | cut -d'-' -f 1)
        echo "lustre_disk_health,disk_type=ost,fs=${fs},disk_id=${id},name=${name} health_state=${health_state},text_state=\"${text_state}\""
done < "${tfile}"

rm -rf ${tfile}
