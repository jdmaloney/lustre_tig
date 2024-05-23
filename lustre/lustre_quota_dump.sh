#!/bin/bash

source /etc/telegraf/lustre/lustre_config

targets=($(ls /proc/fs/lustre/osd-ldiskfs/ | grep -v -i mgs))

for t in ${targets[@]}
do
	pool=$(awk -v target=${t} '$2 == target {print $1}' ${admin_dir}/pool_map)
	target_type=$(echo "${t}" | cut -d'-' -f 2 | cut -c 1-3)
	if [ "${target_type}" == "OST" ]; then
		cat /proc/fs/lustre/osd-ldiskfs/${t}/quota_slave/acct_user | tail -n +2 | paste - - -d" " | awk '{print $3" "$9}' | sed 's/,//g' > ${admin_dir}/user_${t}_${pool}.txt
		cat /proc/fs/lustre/osd-ldiskfs/${t}/quota_slave/acct_group | tail -n +2 | paste - - -d" " | awk '{print $3" "$9}' | sed 's/,//g' > ${admin_dir}/group_${t}_${pool}.txt
		cat /proc/fs/lustre/osd-ldiskfs/${t}/quota_slave/acct_project | tail -n +2 | paste - - -d" " | awk '{print $3" "$9}' | sed 's/,//g' > ${admin_dir}/project_${t}_${pool}.txt
		OST_index=$(echo "${t}" | cut -d'-' -f 2 | cut -c 4-)
                index_value=$(fold -w1 <<< ${OST_index} | paste -sd+ - | bc)
                if [ ${index_value} -eq 0 ]; then
                        cat /proc/fs/lustre/osd-ldiskfs/${t}/quota_slave/limit_user | tail -n +2 | paste - - -d" " | awk '{print $3" "$7" "$9}' | sed 's/,//g' > ${admin_dir}/blimit_user_${t}_${pool}.txt
                        cat /proc/fs/lustre/osd-ldiskfs/${t}/quota_slave/limit_group | tail -n +2 | paste - - -d" " | awk '{print $3" "$7" "$9}' | sed 's/,//g' > ${admin_dir}/blimit_group_${t}_${pool}.txt
                        cat /proc/fs/lustre/osd-ldiskfs/${t}/quota_slave/limit_project | tail -n +2 | paste - - -d" " | awk '{print $3" "$7" "$9}' | sed 's/,//g' > ${admin_dir}/blimit_project_${t}_${pool}.txt
                fi
	elif [ "${target_type}" == "MDT" ]; then
		cat /proc/fs/lustre/osd-ldiskfs/${t}/quota_slave/acct_user | tail -n +2 | paste - - -d" " | awk '{print $3" "$9" "$7}' | sed 's/,//g' > ${admin_dir}/user_${t}_${pool}.txt
		cat /proc/fs/lustre/osd-ldiskfs/${t}/quota_slave/acct_group | tail -n +2 | paste - - -d" " | awk '{print $3" "$9" "$7}' | sed 's/,//g' > ${admin_dir}/group_${t}_${pool}.txt
		cat /proc/fs/lustre/osd-ldiskfs/${t}/quota_slave/acct_project | tail -n +2 | paste - - -d" " | awk '{print $3" "$9" "$7}' | sed 's/,//g' > ${admin_dir}/project_${t}_${pool}.txt
		MDT_index=$(echo "${t}" | cut -d'-' -f 2 | cut -c 4-)
		index_value=$(fold -w1 <<< ${MDT_index} | paste -sd+ - | bc)
		if [ ${index_value} -eq 0 ]; then
			cat /proc/fs/lustre/osd-ldiskfs/${t}/quota_slave/limit_user | tail -n +2 | paste - - -d" " | awk '{print $3" "$7" "$9}' | sed 's/,//g' > ${admin_dir}/flimit_user_${t}.txt
	                cat /proc/fs/lustre/osd-ldiskfs/${t}/quota_slave/limit_group | tail -n +2 | paste - - -d" " | awk '{print $3" "$7" "$9}' | sed 's/,//g' > ${admin_dir}/flimit_group_${t}.txt
        	        cat /proc/fs/lustre/osd-ldiskfs/${t}/quota_slave/limit_project | tail -n +2 | paste - - -d" " | awk '{print $3" "$7" "$9}' | sed 's/,//g' > ${admin_dir}/flimit_project_${t}.txt
		fi
	else
		echo "Error in type"
	fi
done
