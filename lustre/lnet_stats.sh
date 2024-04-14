#!/bin/bash

source /etc/telegraf/lustre_config

stats_line=$(sudo /usr/sbin/lnetctl stats show | sed 's/:\ /=/' | tail -n +2 | xargs | sed 's/\ /,/g')

echo "lnet_stats,fs=${fs} ${stats_line}"

tfile=$(mktemp /tmp/lnet.XXXXXXX)
counter_types=(statistics sent_stats received_stats dropped_stats health_stats)

nets=($(/usr/sbin/lnetctl net show | grep "net\ type:" | grep -v ":\ lo" | awk '{print $NF}' | xargs))

for n in ${nets[@]}
do
	/usr/sbin/lnetctl net show --net ${n} -v 3 | sed 's/health\ stats:/health_stats:/' > "${tfile}"
	interfaces=($(grep -A1 interfaces "${tfile}" | grep "0:" | awk '{print $NF}' | xargs))
	for i in ${interfaces[@]}
	do
		status=$(grep -B2 ${i} ${tfile} | grep status | awk '{print $NF}')
		if [ "${status}" == "up" ]; then
			echo "lnet_detail_stats,fs=${fs},net=${n},interface=${i},counter_type=status state=\"${status}\",is_up=1"
		else
			echo "lnet_detail_stats,fs=${fs},net=${n},interface=${i},counter_type=status state=\"${status}\",is_up=0"
		fi
		for c in ${counter_types[@]}
		do
			if [ ${c} == "statistics" ]; then
				stats_line=$(grep -A 31 "0: ${i}" "${tfile}" | grep -A 3 "statistics" | tail -n +2 | sed 's/:\ /=/' | xargs | sed 's/\ /,/g')
			elif [ ${c} == "health_stats" ]; then
				stats_line=$(grep -A 31 "0: ${i}" "${tfile}" | grep -A 8 "health_stats" | tail -n +2 | sed 's/:\ /=/' | xargs | sed 's/\ /,/g')
			else
				stats_line=$(grep -A 31 "0: ${i}" "${tfile}" | grep -A 5 "${c}" | tail -n +2 | sed 's/:\ /=/' | xargs | sed 's/\ /,/g')
			fi
			echo "lnet_detail_stats,fs=${fs},net=${n},interface=${i},counter_type=${c} ${stats_line}"
		done
	done
done

rm -rf "${tfile}"
