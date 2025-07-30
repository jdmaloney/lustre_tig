#!/bin/bash

source /etc/telegraf/lustre/lustre_config

targets=($(ls /proc/fs/lustre/osd-ldiskfs/ | grep -i mdt))

for t in ${targets[@]}
do
        cat /proc/fs/lustre/osd-ldiskfs/${t}/quota_slave/acct_user | tail -n +2 | paste - - -d" " | awk '{print $3" "$9" "$7}' | sed 's/,//g' > ${admin_dir}/user_${t}_MDT.txt
        cat /proc/fs/lustre/osd-ldiskfs/${t}/quota_slave/acct_group | tail -n +2 | paste - - -d" " | awk '{print $3" "$9" "$7}' | sed 's/,//g' > ${admin_dir}/group_${t}_MDT.txt
        cat /proc/fs/lustre/osd-ldiskfs/${t}/quota_slave/acct_project | tail -n +2 | paste - - -d" " | awk '{print $3" "$9" "$7}' | sed 's/,//g' > ${admin_dir}/project_${t}_MDT.txt
done

target_checks=($(lctl get_param osd-ldiskfs.*.quota_slave.enabled | xargs))
for t in ${target_checks[@]}
do
        target=$(echo ${t} | cut -d'.' -f 2)
        state=$(echo ${t} | cut -d'=' -f 2)
        if [ "${state}" == "${expected_q_state}" ]; then
                echo "lustre_q_enforce_check,fs=${fs},target=${target} enforce_error=0,state=\"${state}\""
        else
                echo "lustre_q_enforce_check,fs=${fs},target=${target} enforce_error=1,state=\"${state}\""
        fi
done
