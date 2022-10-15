#!/bin/bash

## Check if an MDS
mdt_mount=$(grep mdt /proc/mounts | awk '$3 == "lustre" {print $0}')
if [ -n "${mdt_mount}" ]; then

tfile=$(mktemp /tmp/hacheck.XXXXXXX)

sudo /usr/bin/env "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/opt/ddn/es/tools:/opt/ddn/scalers/tools:/root/bin" /opt/ddn/es/tools/hastatus -s | sed -n '/Failed\ Resource\ Actions/q;p' > "${tfile}"
cluster_state=$(cut -d':' -f 1 "${tfile}" | cut -d' ' -f 2-)
if [ "${cluster_state}" == "OK" ]; then
	cluster_health=0
else
	cluster_health=1
fi
echo "lustre_ha_health,service=cluster_health cluster_state=\"${cluster_state}\",cluster_health=${cluster_health}"
sudo /usr/bin/env "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/opt/ddn/es/tools:/opt/ddn/scalers/tools:/root/bin" /opt/ddn/es/tools/hastatus -R | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" | sed -n '/Failed\ Resource\ Actions/q;p' > "${tfile}"
while IFS= read -r line; do
        IFS=" " read -r node state <<< "$(echo ${line})"
	if [ "${state}" == "online" ]; then
		state_health=0
	else
		state_health=1
	fi
        echo "lustre_ha_health,node=${node},service=node state=\"${state}\",state_health=${state_health}"
done <<< "$(cat ${tfile} | grep "Node" | awk '{print $2" "$4}')"
nodes=$(grep "Node" ${tfile} | awk '{print $2}')
for n in ${nodes[@]}
do
	while IFS= read -r line; do
		IFS=" " read -r service state <<< "$(echo ${line})"
		if [ "${state}" == "Started" ]; then
			state_health=0
		else
			state_health=1
		fi
		echo "lustre_ha_health,node=${n},service=${service} state=\"${state}\",state_health=${state_health}"
	done <<< "$(cat ${tfile} | sed -n '/^Node '${n}'/,$p' | sed -n '/^Node/{:1;p;n;/^Node/{p;q};b1};p' | grep -v "Node " | grep ":" | awk '{print $1" "$3}')"
done

rm -rf "${tfile}"

else
	:
fi