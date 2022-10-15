#!/bin/bash

source /etc/telegraf/lustre/lustre_config

## Make Master ID lists
user_ids=($(cat ${admin_dir}/*_user_quota | sort -nu | xargs))
group_ids=($(cat ${admin_dir}/*_group_quota | sort -nu | xargs))
project_ids=($(cat ${admin_dir}/*_project_quota | sort -nu | xargs))

## Parse UIDs
for u in ${user_ids[@]}
do
	while IFS= read -r line; do
                IFS=" " read -r kb_used kb_quota kb_limit kb_grace file_count file_quota file_limit file_grace <<< "${line}"
        done < <(lfs quota -u ${u} ${fs} | grep ${fs} | sed 's/*//g' | awk '{print $2" "$3" "$4" "$5" "$6" "$7" "$8" "$9}' | sed 's/-/0/g')
	user_name=$(awk -v u="${u}" -F: '$3 == u {print $1}' ${admin_dir}/getent_passwd)
	if [ -z ${user_name} ]; then
		user_name="NotFound"
	fi
	if [ "${kb_grace}" == "none" ] || [ "${kb_grace}" == "0" ] || [ "${kb_grace}" == "-" ]; then
		kb_grace=0
        else
		days=$(echo ${kb_grace} | cut -d'd' -f 1)
		hours=$(echo ${kb_grace} | cut -d'd' -f 2 | cut -d'h' -f 1)
		minutes=$(echo ${kb_grace} | cut -d'h' -f 2 | cut -d'm' -f 1)
		seconds=$(echo ${kb_grace} | cut -d'm' -f 2 | cut -d's' -f 1)
		time=$((days*86400 + hours*3600 + minutes*60 * seconds))
		kb_grace=${time}
	fi
	if [ "${file_grace}" == "none" ] || [ "${file_grace}" == "0" ] || [ "${file_grace}" == "-" ]; then
                file_grace=0
        else
                days=$(echo ${file_grace} | cut -d'd' -f 1)
                hours=$(echo ${file_grace} | cut -d'd' -f 2 | cut -d'h' -f 1)
                minutes=$(echo ${file_grace} | cut -d'h' -f 2 | cut -d'm' -f 1)
                seconds=$(echo ${file_grace} | cut -d'm' -f 2 | cut -d's' -f 1)
                time=$((days*86400 + hours*3600 + minutes*60 * seconds))
		file_grace=${time}
        fi
        	echo "lustre_quota,fs=${fs},user_id=${u},user=${user_name} kb_used=${kb_used},kb_quota=${kb_quota},kb_limit=${kb_limit},kb_grace=${kb_grace},files=${file_count},file_quota=${file_quota},file_limit=${file_limit},file_grace=${file_grace}"
done

## Parse GIDs
for g in ${group_ids[@]}
do
	while IFS= read -r line; do
                IFS=" " read -r kb_used kb_quota kb_limit kb_grace file_count file_quota file_limit file_grace <<< "${line}"
        done < <(lfs quota -g ${g} ${fs} | grep ${fs} | sed 's/*//g' | awk '{print $2" "$3" "$4" "$5" "$6" "$7" "$8" "$9}' | sed 's/-/0/g')
	group_name=$(awk -v g="${g}" -F: '$3 == g {print $1}' ${admin_dir}/getent_group)
	if [ -z ${group_name} ]; then
                group_name="NotFound"
        fi
	if [ "${kb_grace}" == "none" ] || [ "${kb_grace}" == "0" ] || [ "${kb_grace}" == "-" ]; then
		kb_grace=0
        else
                days=$(echo ${kb_grace} | cut -d'd' -f 1)
                hours=$(echo ${kb_grace} | cut -d'd' -f 2 | cut -d'h' -f 1)
                minutes=$(echo ${kb_grace} | cut -d'h' -f 2 | cut -d'm' -f 1)
                seconds=$(echo ${kb_grace} | cut -d'm' -f 2 | cut -d's' -f 1)
                time=$((days*86400 + hours*3600 + minutes*60 * seconds))
                kb_grace=${time}
        fi
	if [ "${file_grace}" == "none" ] || [ "${file_grace}" == "0" ] || [ "${file_grace}" == "-" ]; then
		file_grace=0
        else
		days=$(echo ${file_grace} | cut -d'd' -f 1)
                hours=$(echo ${file_grace} | cut -d'd' -f 2 | cut -d'h' -f 1)
                minutes=$(echo ${file_grace} | cut -d'h' -f 2 | cut -d'm' -f 1)
                seconds=$(echo ${file_grace} | cut -d'm' -f 2 | cut -d's' -f 1)
                time=$((days*86400 + hours*3600 + minutes*60 * seconds))
                file_grace=${time}
        fi
        echo "lustre_quota,fs=${fs},group_id=${g},group=${group_name} kb_used=${kb_used},kb_quota=${kb_quota},kb_limit=${kb_limit},kb_grace=${kb_grace},files=${file_count},file_quota=${file_quota},file_limit=${file_limit},file_grace=${file_grace}"
done

## Parse Project IDs
for p in ${project_ids[@]}
do
	while IFS= read -r line; do
		IFS=" " read -r kb_used kb_quota kb_limit kb_grace file_count file_quota file_limit file_grace <<< "${line}"
	done < <(lfs quota -p ${p} ${fs} | grep ${fs} | sed 's/*//g' | awk '{print $2" "$3" "$4" "$5" "$6" "$7" "$8" "$9}' | sed 's/-/0/g')
	project_name=$(awk -v p="${p}" -F: '$3 == p {print $1}' ${admin_dir}/getent_group)
	if [ "${kb_grace}" == "none" ] || [ "${kb_grace}" == "0" ] || [ "${kb_grace}" == "-" ]; then
                kb_grace=0
        else
		days=$(echo ${kb_grace} | cut -d'd' -f 1)
                hours=$(echo ${kb_grace} | cut -d'd' -f 2 | cut -d'h' -f 1)
                minutes=$(echo ${kb_grace} | cut -d'h' -f 2 | cut -d'm' -f 1)
                seconds=$(echo ${kb_grace} | cut -d'm' -f 2 | cut -d's' -f 1)
                time=$((days*86400 + hours*3600 + minutes*60 * seconds))
                kb_grace=${time}
        fi
	if [ "${file_grace}" == "none" ] || [ "${file_grace}" == "0" ] || [ "${file_grace}" == "-" ]; then
		file_grace=0
        else
		days=$(echo ${file_grace} | cut -d'd' -f 1)
                hours=$(echo ${file_grace} | cut -d'd' -f 2 | cut -d'h' -f 1)
                minutes=$(echo ${file_grace} | cut -d'h' -f 2 | cut -d'm' -f 1)
                seconds=$(echo ${file_grace} | cut -d'm' -f 2 | cut -d's' -f 1)
                time=$((days*86400 + hours*3600 + minutes*60 * seconds))
                file_grace=${time}
        fi
	echo "lustre_quota,fs=${fs},project_id=${p},project_name=${project_name} kb_used=${kb_used},kb_quota=${kb_quota},kb_limit=${kb_limit},kb_grace=${kb_grace},files=${file_count},file_quota=${file_quota},file_limit=${file_limit},file_grace=${file_grace}"
done
