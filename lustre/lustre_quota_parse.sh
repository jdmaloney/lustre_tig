#!/bin/bash

source /etc/telegraf/lustre/lustre_config

track_file=$(mktemp /tmp/qtrack.XXXXXX)
pools=($(awk '{print $1}' ${admin_dir}/pool_map | sort -u))

parse_user_quotas () {
	tfile1=$(mktemp /tmp/qparse1.XXXXXX)
	tfile2=$(mktemp /tmp/qparse2.XXXXXX)
	tfile3=$(mktemp /tmp/qparse3.XXXXXX)
	uids=($(cat ${admin_dir}/user*.txt | awk '{print $1}' | sort -u))

	for o in ${pools[@]}
	do
		if [ ${o} == "all" ]; then
			awk '{a[$1]+=$2;b[$1]+=$3}END{for(i in a)print i, a[i], b[i]|"sort"}' ${admin_dir}/user*.txt > ${tfile1}.${o}
			awk '{a[$1]+=$2;b[$1]+=$3}END{for(i in a)print i, a[i], b[i]|"sort"}' ${admin_dir}/blimit_user*.txt > ${tfile2}.${o}
		else
			awk '{a[$1]+=$2;b[$1]+=$3}END{for(i in a)print i, a[i], b[i]|"sort"}' ${admin_dir}/user*_${o}.txt ${admin_dir}/user*_all.txt > ${tfile1}.${o}
			awk '{a[$1]+=$2;b[$1]+=$3}END{for(i in a)print i, a[i], b[i]|"sort"}' ${admin_dir}/blimit_user*_${o}.txt > ${tfile2}.${o}
		fi
	done
	awk '{a[$1]+=$2;b[$1]+=$3}END{for(i in a)print i, a[i], b[i]|"sort"}' ${admin_dir}/flimit_user*.txt > ${tfile3}
	blimit_count=$(cat ${tfile2}.* | wc -l | awk '{print $1}')
	flimit_count=$(wc -l ${tfile3} | awk '{print $1}')

	for u in ${uids[@]}
	do
		user_name=$(awk -v u="${u}" -F: '$3 == u {print $1}' ${admin_dir}/getent_passwd)
		if [ -z "${user_name}" ]; then
			user_name="NotFound"
		fi
		if [ ${flimit_count} -gt 2 ]; then
	                read -r file_limit file_quota <<< $(awk -v u=${u} '$1 == u {print $2" "$3}' ${tfile3})
	                if [ -z "${file_limit}" ]; then
	       	                 file_limit=0
	                fi
	                if [ -z "${file_quota}" ]; then
	                        file_quota=0
			fi
		else
	                file_limit=0
	                file_quota=0
	        fi
		for o in ${pools[@]}
		do
			read -r kb_used inodes <<< $(awk -v u=${u} '$1 == u {print $2" "$3}' ${tfile1}.${o})
			if [ -z "${kb_used}" ]; then
				kb_used=0
			fi
			if [ -z "${inodes}" ]; then
				inodes=0
			fi
			if [ ${blimit_count} -gt 2 ]; then
		                read -r kb_limit kb_quota <<< $(awk -v u=${u} '$1 == u {print $2" "$3}' ${tfile2}.${o})
		                if [ -z "${kb_limit}" ]; then
		                        kb_limit=0
		                fi
		                if [ -z "${kb_quota}" ]; then
		                        kb_quota=0
		                fi
		        else
		                kb_limit=0
		                kb_quota=0
		        fi
			echo "lustre_quota,fs=${fs},pool=${o},user_id=${u},user=${user_name} kb_used=${kb_used},kb_quota=${kb_quota},kb_limit=${kb_limit},files=${inodes},file_quota=${file_quota},file_limit=${file_limit}"
		done
		mdts=($(ls ${admin_dir}/user*MDT*.txt | rev | cut -d'_' -f 2 | rev))
		for m in ${mdts[@]}
		do
			read -r kb_used inodes <<< $(awk -v u=${u} '$1 == u {print $2" "$3}' ${admin_dir}/user_${m}_all.txt)
        	        if [ -z "${kb_used}" ]; then
        	                kb_used=0
        	        fi
        	        if [ -z "${inodes}" ]; then
        	                inodes=0
        	        fi
			echo "lustre_quota,fs=${fs},pool=mdt,user_id=${u},user=${user_name},mdt=${m} kb_used=${kb_used},files=${inodes}"
		done
	done
        rm -f /tmp/qparse1*
        rm -f /tmp/qparse2*
        rm -f /tmp/qparse3*
	echo "done" >> ${track_file}
}


parse_group_quotas () {
	tfile4=$(mktemp /tmp/qparse4.XXXXXX)
        tfile5=$(mktemp /tmp/qparse5.XXXXXX)
        tfile6=$(mktemp /tmp/qparse6.XXXXXX)
	gids=($(cat ${admin_dir}/group*.txt | awk '{print $1}' | sort -u))

	for o in ${pools[@]}
	do
		if [ ${o} == "all" ]; then
			awk '{a[$1]+=$2;b[$1]+=$3}END{for(i in a)print i, a[i], b[i]|"sort"}' ${admin_dir}/group*.txt > ${tfile4}.${o}
			awk '{a[$1]+=$2;b[$1]+=$3}END{for(i in a)print i, a[i], b[i]|"sort"}' ${admin_dir}/blimit_group*.txt > ${tfile5}.${o}
		else
			awk '{a[$1]+=$2;b[$1]+=$3}END{for(i in a)print i, a[i], b[i]|"sort"}' ${admin_dir}/group*_${o}.txt ${admin_dir}/group*_all.txt > ${tfile4}.${o}
	                awk '{a[$1]+=$2;b[$1]+=$3}END{for(i in a)print i, a[i], b[i]|"sort"}' ${admin_dir}/blimit_group*_${o}.txt > ${tfile5}.${o}
		fi
	done
	awk '{a[$1]+=$2;b[$1]+=$3}END{for(i in a)print i, a[i], b[i]|"sort"}' ${admin_dir}/flimit_group*.txt > ${tfile6}
	blimit_count=$(cat ${tfile5}.* | wc -l | awk '{print $1}')
	flimit_count=$(wc -l ${tfile6} | awk '{print $1}')

	for g in ${gids[@]}
	do
		group_name=$(awk -v g="${g}" -F: '$3 == g {print $1}' ${admin_dir}/getent_group)
		if [ -z "${group_name}" ]; then
	                group_name="NotFound"
	        fi
		if [ ${flimit_count} -gt 2 ]; then
			read -r file_limit file_quota <<< $(awk -v g=${g} '$1 == g {print $2" "$3}' ${tfile6})
			if [ -z "${file_limit}" ]; then
		                file_limit=0
		        fi
		        if [ -z "${file_quota}" ]; then
		                file_quota=0
		        fi
		else
			file_limit=0
			file_quota=0
		fi
		for o in ${pools[@]}
		do
		        read -r kb_used inodes <<< $(awk -v g=${g} '$1 == g {print $2" "$3}' ${tfile4}.${o})
	                if [ -z "${kb_used}" ]; then
	                        kb_used=0
	                fi
	                if [ -z "${inodes}" ]; then
	                        inodes=0
	                fi
			if [ ${blimit_count} -gt 2 ]; then
				read -r kb_limit kb_quota <<< $(awk -v g=${g} '$1 == g {print $2" "$3}' ${tfile5}.${o})
				if [ -z "${kb_limit}" ]; then
			                kb_limit=0
			        fi
			        if [ -z "${kb_quota}" ]; then
			                kb_quota=0
			        fi
			else
				kb_limit=0
				kb_quota=0
			fi
		        echo "lustre_quota,fs=${fs},pool=${o},group_id=${g},group=${group_name} kb_used=${kb_used},kb_quota=${kb_quota},kb_limit=${kb_limit},files=${inodes},file_quota=${file_quota},file_limit=${file_limit}"
		done
		mdts=($(ls ${admin_dir}/group*MDT*.txt | rev | cut -d'_' -f 2 | rev))
	        for m in ${mdts[@]}
	        do
	                read -r kb_used inodes <<< $(awk -v g=${g} '$1 == g {print $2" "$3}' ${admin_dir}/group_${m}_all.txt)
	  		if [ -z "${kb_used}" ]; then
	                        kb_used=0
	                fi
	                if [ -z "${inodes}" ]; then
	                        inodes=0
	                fi
			echo "lustre_quota,fs=${fs},pool=mdt,group_id=${g},group=${group_name},mdt=${m} kb_used=${kb_used},files=${inodes}"
	        done
	done
	rm -f /tmp/qparse4*
        rm -f /tmp/qparse5*
        rm -f /tmp/qparse6*
	echo "done" >> ${track_file}
}

parse_project_quotas () {
	tfile7=$(mktemp /tmp/qparse7.XXXXXX)
        tfile8=$(mktemp /tmp/qparse8.XXXXXX)
        tfile9=$(mktemp /tmp/qparse9.XXXXXX)
	pids=($(cat ${admin_dir}/project*.txt | awk '{print $1}' | sort -u))

	for o in ${pools[@]}
	do
		if [ ${o} == "all" ]; then
			awk '{a[$1]+=$2;b[$1]+=$3}END{for(i in a)print i, a[i], b[i]|"sort"}' ${admin_dir}/project*.txt > ${tfile7}.${o}
			awk '{a[$1]+=$2;b[$1]+=$3}END{for(i in a)print i, a[i], b[i]|"sort"}' ${admin_dir}/blimit_project*.txt > ${tfile8}.${o}
		else
			awk '{a[$1]+=$2;b[$1]+=$3}END{for(i in a)print i, a[i], b[i]|"sort"}' ${admin_dir}/project*_${o}.txt ${admin_dir}/project*_all.txt > ${tfile7}.${o}
	                awk '{a[$1]+=$2;b[$1]+=$3}END{for(i in a)print i, a[i], b[i]|"sort"}' ${admin_dir}/blimit_project*_${o}.txt > ${tfile8}.${o}
		fi
	done
	awk '{a[$1]+=$2;b[$1]+=$3}END{for(i in a)print i, a[i], b[i]|"sort"}' ${admin_dir}/flimit_project*.txt > ${tfile9}
	blimit_count=$(cat ${tfile8}.* | wc -l | awk '{print $1}')
	flimit_count=$(wc -l ${tfile9} | awk '{print $1}')

	for p in ${pids[@]}
	do
		project_name=$(awk -v p="${p}" -F: '$3 == p {print $1}' ${admin_dir}/getent_group)
		if [ -z "${project_name}" ]; then
	                project_name="NotFound"
	        fi
		if [ ${flimit_count} -gt 2 ]; then
			read -r file_limit file_quota <<< $(awk -v p=${p} '$1 == p {print $2" "$3}' ${tfile9})
			if [ -z "${file_limit}" ]; then
				file_limit=0
			fi
			if [ -z "${file_quota}" ]; then
				file_quota=0
			fi
		else
			file_limit=0
			file_quota=0
		fi
		for o in ${pools[@]}; do
		        read -r kb_used inodes <<< $(awk -v p=${p} '$1 == p {print $2" "$3}' ${tfile7}.${o})
	                if [ -z "${kb_used}" ]; then
	                        kb_used=0
	                fi
	                if [ -z "${inodes}" ]; then
	                        inodes=0
	                fi
			if [ ${blimit_count} -gt 2 ]; then
		                read -r kb_limit kb_quota <<< $(awk -v p=${p} '$1 == p {print $2" "$3}' ${tfile8}.${o})
		                if [ -z "${kb_limit}" ]; then
		                        kb_limit=0
		                fi
		                if [ -z "${kb_quota}" ]; then
		                        kb_quota=0
		                fi
		        else
		                kb_limit=0
		                kb_quota=0
			        fi
			echo "lustre_quota,fs=${fs},pool=${o},project_id=${p},project_name=${project_name} kb_used=${kb_used},kb_quota=${kb_quota},kb_limit=${kb_limit},files=${inodes},file_quota=${file_quota},file_limit=${file_limit}"
		done
		mdts=($(ls ${admin_dir}/project*MDT*.txt | rev | cut -d'_' -f 2 | rev))
	        for m in ${mdts[@]}
	        do
	                read -r kb_used inodes <<< $(awk -v p=${p} '$1 == p {print $2" "$3}' ${admin_dir}/project_${m}_all.txt)
			if [ -z "${kb_used}" ]; then
				kb_used=0
			fi
			if [ -z "${inodes}" ]; then
				inodes=0
			fi
	                echo "lustre_quota,fs=${fs},pool=mdt,project_id=${p},project_name=${project_name},mdt=${m} kb_used=${kb_used},files=${inodes}"
	        done
	done
	rm -f /tmp/qparse7*
	rm -f /tmp/qparse8*
	rm -f /tmp/qparse9*
	echo "done" >> ${track_file}
}

parse_user_quotas &
parse_group_quotas &
parse_project_quotas &

while [ $(wc -l ${track_file} | awk '{print $1}') -lt 3 ]; do
	sleep 0.5
done
rm -f /tmp/qtrack.*
