#!/bin/bash

tfile=$(mktemp /tmp/lfs.XXXXXX)

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
        echo "lustre_disk_health,disk_type=mdt,fs=${fs},disk_id=${id},name=${name} health_state=${health_state},text_state=${text_state}"
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
        echo "lustre_disk_health,disk_type=ost,fs=${fs},disk_id=${id},name=${name} health_state=${health_state},text_state=${text_state}"
done < "${tfile}"

rm -rf ${tfile}
