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
