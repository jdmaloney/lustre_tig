#!/bin/bash

source /etc/telegraf/lustre/lustre_config

## Node roll; how does it need to participate
if [ -z "$(cat /proc/mounts | grep "MDT")" ]; then
	## No MDTs
	target_checks=($(lctl get_param osd-ldiskfs.*.quota_slave.enabled | xargs))
        for t in ${target_checks[@]}
        do
                target=$(echo ${t} | cut -d'.' -f 2)
                state=$(echo ${t} | cut -d'=' -f 2)
                if [ "${state}" == "${expected_q_state}" ]; then
                        echo "lustre_q_enforce_check,fs=${fs},target=${target} enforce_error=0,state=${state}"
                else
                        echo "lustre_q_enforce_check,fs=${fs},target=${target} enforce_error=1,state=${state}"
                fi
        done
else
	## I have MDT(s), dumping their IDse
	MDTs=($(ls /proc/fs/lustre/osd-ldiskfs/ | grep MDT | xargs))
        for m in ${MDTs[@]}
        do
                lctl get_param osd-ldiskfs.${m}.quota_slave_dt.acct_user | grep id | awk '{print $3}' > ${admin_dir}/${m}_user_quota
                lctl get_param osd-ldiskfs.${m}.quota_slave_dt.acct_group | grep id | awk '{print $3}' > ${admin_dir}/${m}_group_quota
                lctl get_param osd-ldiskfs.${m}.quota_slave_dt.acct_project | grep id | awk '{print $3}' > ${admin_dir}/${m}_project_quota
        done
        target_checks=($(lctl get_param osd-ldiskfs.*.quota_slave.enabled | xargs))
        for t in ${target_checks[@]}
        do
                target=$(echo ${t} | cut -d'.' -f 2)
                state=$(echo ${t} | cut -d'=' -f 2)
                if [ "${state}" == "${expected_q_state}" ]; then
                        echo "lustre_q_enforce_check,fs=${fs},target=${target} enforce_error=0,state=${state}"
                else
                        echo "lustre_q_enforce_check,fs=${fs},target=${target} enforce_error=1,state=${state}"
                fi
        done
fi
