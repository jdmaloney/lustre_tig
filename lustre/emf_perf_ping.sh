#!/bin/bash

tfile=$(mktemp /tmp/perfping.XXXXXXX)

emfperf pingall --csv | tr " ," ", " > "${tfile}"

while IFS=',' read -r line; do
	thost=$(echo ${line} | awk '{print $1}')
	interfaces=($(echo "${line}" | cut -d' ' -f 2-))
	for i in ${interfaces[@]}
	do
		IFS="," read interface state <<< $(echo ${i})
		if [ "${state}" == "OK" ]; then
			interface_error=0
		else
			interface_error=1
		fi
	echo "emfperfpingall,target_host=${thost},interface=${interface} state_string=\"${state}\",interface_error=${interface_error}"
	done
done < "${tfile}"

rm -rf "${tfile}"
