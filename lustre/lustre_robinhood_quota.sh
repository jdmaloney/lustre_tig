#!/bin/bash

source /etc/telegraf/lustre/lustre_config
tfile=$(mktemp /tmp/robinhood_parse.XXXXXXX)

projects=($(mysql -u ${robinhood_user} -p"${robinhood_password}" -D ${robinhood_db} -e "select distinct projid from ACCT_STAT;" | tail -n +2 | xargs))

for p in ${projects[@]}
do
	proj_name=$(getent group ${p} | cut -d':' -f 1)

	## Gather per user stats in each project
	mysql -u ${robinhood_user} -p"${robinhood_password}" -D ${robinhood_db} -e "select uid,sum(size),sum(count) from ACCT_STAT where projid = '"${p}"' GROUP BY uid;" | tail -n +2 > "${tfile}"
	while read -r line; do
		IFS=" " read -r user_name bytes_used inodes <<< $(echo ${line})
		IFS=" " read -r sz0 sz1 sz32 sz1K sz32K sz1M sz32M sz1G sz32G sz1T <<< $(mysql -u ${robinhood_user} -p"${robinhood_password}" -D ${robinhood_db} -e "select sum(sz0),sum(sz1),sum(sz32),sum(sz1K),sum(sz32K),sum(sz1M),sum(sz32M),sum(sz1G),sum(sz32G),sum(sz1T) from ACCT_STAT where uid = '"${user_name}"' and projid = '"${p}"' and type = 'file';" | tail -n +2 | sed 's/\t/\ /g' | sed 's/NULL/0/g')
		echo "lustre_robinhood_quota,fs=${fs},project_id=${p},project_name=${proj_name},user_name=${user_name} bytes_used=${bytes_used},inodes=${inodes},sz0=${sz0},sz1=${sz1},sz32=${sz32},sz1K=${sz1K},sz32K=${sz32K},sz1M=${sz1M},sz32M=${sz32M},sz1G=${sz1G},sz32G=${sz32G},sz1T=${sz1T}"
	done <"${tfile}"

	## Gather per group stats in each project
	mysql -u ${robinhood_user} -p"${robinhood_password}" -D ${robinhood_db} -e "select gid,sum(size),sum(count) from ACCT_STAT where projid = '"${p}"' GROUP BY gid;" | tail -n +2 > "${tfile}"
        while read -r line; do
                IFS=" " read -r group_name bytes_used inodes <<< $(echo ${line})
                IFS=" " read -r sz0 sz1 sz32 sz1K sz32K sz1M sz32M sz1G sz32G sz1T <<< $(mysql -u ${robinhood_user} -p"${robinhood_password}" -D ${robinhood_db} -e "select sum(sz0),sum(sz1),sum(sz32),sum(sz1K),sum(sz32K),sum(sz1M),sum(sz32M),sum(sz1G),sum(sz32G),sum(sz1T) from ACCT_STAT where gid = '"${group_name}"' and projid = '"${p}"' and type = 'file';" | tail -n +2 | sed 's/\t/\ /g' | sed 's/NULL/0/g')
                echo "lustre_robinhood_quota,fs=${fs},project_id=${p},project_name=${proj_name},group_name=${group_name} bytes_used=${bytes_used},inodes=${inodes},sz0=${sz0},sz1=${sz1},sz32=${sz32},sz1K=${sz1K},sz32K=${sz32K},sz1M=${sz1M},sz32M=${sz32M},sz1G=${sz1G},sz32G=${sz32G},sz1T=${sz1T}"
        done <"${tfile}"

	## Gather Aggregate Project Histogram
	IFS=" " read -r sz0 sz1 sz32 sz1K sz32K sz1M sz32M sz1G sz32G sz1T <<< $(mysql -u ${robinhood_user} -p"${robinhood_password}" -D ${robinhood_db} -e "select sum(sz0),sum(sz1),sum(sz32),sum(sz1K),sum(sz32K),sum(sz1M),sum(sz32M),sum(sz1G),sum(sz32G),sum(sz1T) from ACCT_STAT where projid = '"${p}"' and type = 'file';" | tail -n +2 | sed 's/\t/\ /g' | sed 's/NULL/0/g')
                echo "lustre_robinhood_quota,fs=${fs},project_id=${p},project_name=${proj_name},type=full_project bytes_used=${bytes_used},inodes=${inodes},sz0=${sz0},sz1=${sz1},sz32=${sz32},sz1K=${sz1K},sz32K=${sz32K},sz1M=${sz1M},sz32M=${sz32M},sz1G=${sz1G},sz32G=${sz32G},sz1T=${sz1T}"
done

## GET FS-Wide File Histograms
IFS=" " read -r sz0 sz1 sz32 sz1K sz32K sz1M sz32M sz1G sz32G sz1T <<< $(mysql -u ${robinhood_user} -p"${robinhood_password}" -D ${robinhood_db} -e "select sum(sz0),sum(sz1),sum(sz32),sum(sz1K),sum(sz32K),sum(sz1M),sum(sz32M),sum(sz1G),sum(sz32G),sum(sz1T) from ACCT_STAT where type = 'file';" | tail -n +2 | sed 's/\t/\ /g')
echo "lustre_robinhood_quota,fs=${fs},histogram_type=file sz0=${sz0},sz1=${sz1},sz32=${sz32},sz1K=${sz1K},sz32K=${sz32K},sz1M=${sz1M},sz32M=${sz32M},sz1G=${sz1G},sz32G=${sz32G},sz1T=${sz1T}"

IFS=" " read -r sz0 sz1 sz32 sz1K sz32K sz1M sz32M sz1G sz32G sz1T <<< $(mysql -u ${robinhood_user} -p"${robinhood_password}" -D ${robinhood_db} -e "select sum(sz0),sum(sz1),sum(sz32),sum(sz1K),sum(sz32K),sum(sz1M),sum(sz32M),sum(sz1G),sum(sz32G),sum(sz1T) from ACCT_STAT where type = 'dir';" | tail -n +2 | sed 's/\t/\ /g')
echo "lustre_robinhood_quota,fs=${fs},histogram_type=dir sz0=${sz0},sz1=${sz1},sz32=${sz32},sz1K=${sz1K},sz32K=${sz32K},sz1M=${sz1M},sz32M=${sz32M},sz1G=${sz1G},sz32G=${sz32G},sz1T=${sz1T}"

rm -rf "${tfile}"
