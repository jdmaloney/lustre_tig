#!/bin/bash

if [ -z "$(cat /proc/mounts | grep "MDT")" ]; then
        ## No MDTs, just exit
        exit 0
else

	tfile=$(mktemp /tmp/backlog.XXXXXX)

	sudo /usr/sbin/lctl get_param mdd.*.changelog_* > "${tfile}"

	fs=$(head -n 1 "${tfile}" | cut -d'.' -f 2 | cut -d'-' -f 1)
	mdt=$(head -n 1 "${tfile}" | cut -d'-' -f 2 | cut -d'.' -f 1)
	changelog_size=$(grep changelog_size "${tfile}" | cut -d'=' -f 2)
	current_index=$(awk '$1 ~ "^current_index.*" {print $2}' "${tfile}")
	indexes=($(grep -A20 ID "${tfile}" | awk '{print $1}' | grep -v ID | xargs))
	for i in ${indexes[@]}
	do
		consumer_index=$(awk -v i=$i '$1 == i {print $2}' "${tfile}")
		backlog=$((current_index-consumer_index))
		echo "lustre_backlog,mdt=${mdt},fs=${fs},index_id=${i} backlog=${backlog},current_index=${current_index},consumer_index=${consumer_index},changelog_size=${changelog_size}"
	done

	rm -rf ${tfile}
fi
