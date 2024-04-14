#!/bin/bash

source /etc/telegraf/lustre/lustre_config

## Lustre Ping
for m in ${mgs[@]}
do
	lping=$(sudo /usr/sbin/lctl ping ${m} | head -n 1)
	
	if [ -z $(echo ${lping} | grep -i error) ]; then
		echo "lctl_ping,target=${m} ping_error=0"
	else
		echo "lctl_ping,target=${m} ping_error=1"
	fi
done

## FS Responsive Test ##
tfile1=$(mktemp /tmp/ls.XXXXXX)
tfile2=$(mktemp /tmp/stat.XXXXXXX)

for p in ${paths[@]}
do
	{ time ls ${p} ; } 2> ${tfile1} 1> /dev/null
	min=$(cat ${tfile1} | grep real | awk '{print $2}' | cut -d'm' -f 1)
	sec=$(cat ${tfile1} | grep real | awk '{print $2}' | cut -d'm' -f 2 | cut -d's' -f 1)
	time=$( bc -l <<<"60*$min + $sec" )
	echo fs_ls_time,path=${p} duration=${time}
done

for f in ${files[@]}
do
	{ time stat ${f} ; } 2> ${tfile2} 1> /dev/null
	min=$(cat ${tfile2} | grep real | awk '{print $2}' | cut -d'm' -f 1)
	sec=$(cat ${tfile2} | grep real | awk '{print $2}' | cut -d'm' -f 2 | cut -d's' -f 1)
	time=$( bc -l <<<"60*$min + $sec" )
	echo fs_stat_time,path=${f} duration=${time}
done

rm -rf ${tfile1}
rm -rf ${tfile2}

## FS Mount Check
for f in ${fs[@]}
do
        check=$(grep $f /proc/mounts | grep lustre)
                if [ -n "$check" ]; then
			#It's in /proc/mounts
                	proc_check=0
		else
			proc_check=1
		fi
	stat=$(stat ${files[0]})
	if [ -n "$stat" ]; then
		#We can stat a file
		stat_check=0
	else
		stat_check=1
	fi
	if [ $proc_check -eq 0 ] && [ $stat_check -eq 0 ]; then
		#All is healthy
		echo "mountcheck,fs=${f} presence=1"
	else
		echo "mountcheck,fs=${f} presence=0"
	fi

done

## MDT/OST Activity
while IFS= read -r line; do
	IFS=" " read -r target active_string <<< "${line}"
	if [ "${active_string}" == "ACTIVE" ]; then
		active=1
	else
		active=0
	fi
	echo "lfs_mdt_ost_check,target=${target} active=${active},active_string=\"${active_string}\""
done < <(lfs mdts | awk '{print $2" "$3}' | sort -u | sed '/^[[:space:]]*$/d')

while IFS= read -r line; do
        IFS=" " read -r target active_string <<< "${line}"
        if [ "${active_string}" == "ACTIVE" ]; then
                active=1
        else
                active=0
        fi
        echo "lfs_mdt_ost_check,target=${target} active=${active},active_string=\"${active_string}\""
done < <(lfs osts | awk '{print $2" "$3}' | sort -u | sed '/^[[:space:]]*$/d')

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

tfile=$(mktemp /tmp/rpcs.XXXXXXX)

file_systems=$(ls /proc/fs/lustre/osc/ | cut -d'-' -f 1 | sort -u | xargs)
for f in ${file_systems[@]}
do
	pools=($(/usr/sbin/lctl pool_list ${f} | tail -n +2))
	for p in ${pools[@]}
	do
		lctl pool_list ${p} | tail -n +2 | sed "s/^/${p}:/" | sed 's/_UUID//' >> "${tfile}".pools
	done
	rrpc_inflight=0
	wrpc_inflight=0
	targets=($(ls /proc/fs/lustre/osc/ | grep "${f}-"))
	for t in ${targets[@]}
	do
		cleant=$(echo ${t} | cut -d'-' -f 1-2)
		pool=$(grep "${cleant}" "${tfile}".pools | cut -d':' -f 1 | cut -d'.' -f 2)
		cat /proc/fs/lustre/osc/${t}/rpc_stats > "${tfile}"
		read -r n_rrpc_inflight n_wrpc_inflight <<< $(grep "RPCs in flight" ${tfile} | awk '{print $NF}' | xargs)
		rrpc_inflight=$((n_rrpc_inflight+rrpc_inflight))
		wrpc_inflight=$((n_wrpc_inflight+wrpc_inflight))

		## RPC Size Info
		awk 'index($0,"pages per rpc"){p=1}p{if(/^$/){exit};print}' "${tfile}" | tail -n +2 |  awk -v pool="${pool}" '{print $1" "$2" "$6" "pool}' | sed 's/://' >> "${tfile}".size

		## RPC Inflight
		awk 'index($0,"rpcs in flight"){p=1}p{if(/^$/){exit};print}' "${tfile}" | tail -n +2 |  awk -v pool="${pool}" '{print $1" "$2" "$6" "pool}' | sed 's/://' >> "${tfile}".inflight
	done

	echo "lustre_client_rpc_stats,fs=$f,type=general read_rpcs_in_flight=${rrpc_inflight},write_rpcs_in_flight=${wrpc_inflight}"

       ## Tally Size Info
        pages=($(awk '{print $1}' "${tfile}".size | sort -u | xargs))
        all_rpcs_read=$(awk '{print $2}' "${tfile}".size | paste -sd+ | bc)
        all_rpcs_write=$(awk '{print $3}' "${tfile}".size | paste -sd+ | bc)
        for p in ${pages[@]}
        do
		for l in ${pools[@]}
		do
			real_pool=$(echo ${l} | cut -d'.' -f 2)
			read_rpcs=$(awk -v l=${real_pool} -v p=${p} '$4 == l  && $1 == p {print $2}' "${tfile}".size | paste -sd+ | bc)
			write_rpcs=$(awk -v l=${real_pool} -v p=${p} '$4 == l  && $1 == p {print $3}' "${tfile}".size  | paste -sd+ | bc)
	                read_rpcs_per=$(echo "scale=7; ${read_rpcs}/${all_rpcs_read}*100" | bc -l)
	                write_rpcs_per=$(echo "scale=7; ${write_rpcs}/${all_rpcs_write}*100" | bc -l)
	                echo "lustre_client_rpc_stats,fs=${f},pool=${real_pool},type=pages_per_rpc,pages=${p} read_rpcs=${read_rpcs},read_rpcs_percent=${read_rpcs_per},write_rpcs=${write_rpcs},write_rpcs_percent=${write_rpcs_per}"
		done
	done

        ## Tally Inflight Info
        rpcs=($(awk '{print $1}' "${tfile}".inflight | sort -u | xargs))
        all_rpcs_read=$(awk '{print $2}' "${tfile}".inflight | paste -sd+ | bc)
        all_rpcs_write=$(awk '{print $3}' "${tfile}".inflight | paste -sd+ | bc)
        for r in ${rpcs[@]}
        do
		for l in ${pools[@]}
		do
			real_pool=$(echo ${l} | cut -d'.' -f 2)
	                read_rpcs=$(awk -v l=${real_pool} -v r=${r} '$4 == l  && $1 == r {print $2}' "${tfile}".inflight | paste -sd+ | bc)
	                write_rpcs=$(awk -v l=${real_pool} -v r=${r} '$4 == l  && $1 == r {print $3}' "${tfile}".inflight | paste -sd+ | bc)
			if [ -n "${read_rpcs}" ]; then
				read_rpcs_per=$(echo "scale=7; ${read_rpcs}/${all_rpcs_read}*100" | bc -l)
			else
				read_rpcs=0
				read_rpcs_per=0
			fi
			if [ -n "${write_rpcs}" ]; then
				write_rpcs_per=$(echo "scale=7; ${write_rpcs}/${all_rpcs_write}*100" | bc -l)
			else
				write_rpcs=0
				write_rpcs_per=0
			fi
			echo "lustre_client_rpc_stats,fs=${f},pool=${real_pool},type=rpcs_in_flight,rpcs=${r} read_rpcs=${read_rpcs},read_rpcs_percent=${read_rpcs_per},write_rpcs=${write_rpcs},write_rpcs_percent=${write_rpcs_per}"
		done
	done

done

rm -rf "${tfile}" "${tfile}.size" "${tfile}.inflight" "${tfile}.pools"
