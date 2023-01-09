#!/bin/bash

source /etc/telegraf/lustre/lustre_config

## Node roll; how does it need to participate
if [ -z "$(cat /proc/mounts | grep "MDT")" ]; then
	## No MDTs, just exit
	exit 0
else
	## I have MDT(s), dumping their IDse
	MDTs=($(ls /proc/fs/lustre/osd-ldiskfs/ | grep MDT | xargs))
        for m in ${MDTs[@]}
        do
                lctl get_param osd-ldiskfs.${m}.quota_slave_dt.acct_user | grep id | awk '{print $3}' > ${admin_dir}/${m}_user_quota
                lctl get_param osd-ldiskfs.${m}.quota_slave_dt.acct_group | grep id | awk '{print $3}' > ${admin_dir}/${m}_group_quota
                lctl get_param osd-ldiskfs.${m}.quota_slave_dt.acct_project | grep id | awk '{print $3}' > ${admin_dir}/${m}_project_quota
        done
fi
