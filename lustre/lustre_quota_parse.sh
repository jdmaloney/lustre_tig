#!/bin/bash

source /etc/telegraf/lustre/lustre_config

tfile=$(mktemp /tmp/lustrequota.XXXXXXXX)

pools=($(/usr/sbin/lctl pool_list $filesystem | tail -n +2 | grep -v old | xargs))
mdts=($(ls ${admin_dir}/project_* | cut -d'/' -f 3 | cut -d'_' -f 2))

for i in ${pools[@]}
do
        pool_name=$(echo $i | cut -d'.' -f 2)
        /usr/bin/lfs quota --pool ${i} -u -a ${fs} | awk '{print $2","$3","$4","$5","$7","$8","$9}' | tail -n +3 > "${tfile}"
        while read -r p; do
                IFS="," read -r user kb_used kb_soft kb_hard inode_used inode_soft inode_hard <<< $(echo ${p} | sed 's/\[//g' | sed 's/\]//g' |  sed 's/*//g')
                echo "lustre_quota,fs=${fs},pool=${pool_name},user=${user} kb_used=${kb_used},kb_soft=${kb_soft},kb_hard=${kb_hard},inode_used=${inode_used},inode_soft=${inode_soft},inode_hard=${inode_hard}"
        done<"${tfile}"

        /usr/bin/lfs quota --pool ${i} -g -a ${fs} | awk '{print $2","$3","$4","$5","$7","$8","$9}' | tail -n +3 > "${tfile}"
        while read -r p; do
                IFS="," read -r group kb_used kb_soft kb_hard inode_used inode_soft inode_hard <<< $(echo ${p} | sed 's/\[//g' | sed 's/\]//g' |  sed 's/*//g')
                echo "lustre_quota,fs=${fs},pool=${pool_name},group=${group} kb_used=${kb_used},kb_soft=${kb_soft},kb_hard=${kb_hard},inode_used=${inode_used},inode_soft=${inode_soft},inode_hard=${inode_hard}"
        done<"${tfile}"

        /usr/bin/lfs quota --pool ${i} -p -a ${fs} | awk '{print $2","$3","$4","$5","$7","$8","$9}' | tail -n +3 > "${tfile}"
        while read -r p; do
                IFS="," read -r prjid kb_used kb_soft kb_hard inode_used inode_soft inode_hard <<< $(echo ${p} | sed 's/\[//g' | sed 's/\]//g' |  sed 's/*//g')
                project=$(awk -v prjid=$prjid -F ':' '$3 == prjid {print $1}' ${quota_group})
                project=${project:=none}
                echo "lustre_quota,fs=${fs},pool=${pool_name},project=${project} kb_used=${kb_used},kb_soft=${kb_soft},kb_hard=${kb_hard},inode_used=${inode_used},inode_soft=${inode_soft},inode_hard=${inode_hard}"
        done<"${tfile}"
done

pool_name=all

/usr/bin/lfs quota -u -a ${fs} | awk '{print $2","$3","$4","$5","$7","$8","$9}' | tail -n +3 > "${tfile}"
while read -r p; do
        IFS="," read -r user kb_used kb_soft kb_hard inode_used inode_soft inode_hard <<< $(echo ${p} | sed 's/\[//g' | sed 's/\]//g' |  sed 's/*//g')
        echo "lustre_quota,fs=${fs},pool=${pool_name},user=${user} kb_used=${kb_used},kb_soft=${kb_soft},kb_hard=${kb_hard},inode_used=${inode_used},inode_soft=${inode_soft},inode_hard=${inode_hard}"
done<"${tfile}"

/usr/bin/lfs quota -g -a ${fs} | awk '{print $2","$3","$4","$5","$7","$8","$9}' | tail -n +3 > "${tfile}"
while read -r p; do
        IFS="," read -r group kb_used kb_soft kb_hard inode_used inode_soft inode_hard <<< $(echo ${p} | sed 's/\[//g' | sed 's/\]//g' |  sed 's/*//g')
        echo "lustre_quota,fs=${fs},pool=${pool_name},group=${group} kb_used=${kb_used},kb_soft=${kb_soft},kb_hard=${kb_hard},inode_used=${inode_used},inode_soft=${inode_soft},inode_hard=${inode_hard}"
done<"${tfile}"

/usr/bin/lfs quota -p -a ${fs} | awk '{print $2","$3","$4","$5","$7","$8","$9}' | tail -n +3 > "${tfile}"
while read -r p; do
        IFS="," read -r prjid kb_used kb_soft kb_hard inode_used inode_soft inode_hard <<< $(echo ${p} | sed 's/\[//g' | sed 's/\]//g' |  sed 's/*//g')
        project=$(awk -v prjid=$prjid -F ':' '$3 == prjid {print $1}' ${quota_group})
        project=${project:=none}
        echo "lustre_quota,fs=${fs},pool=${pool_name},project=${project} kb_used=${kb_used},kb_soft=${kb_soft},kb_hard=${kb_hard},inode_used=${inode_used},inode_soft=${inode_soft},inode_hard=${inode_hard}"
done<"${tfile}"

rm -f "${tfile}"

parse_mdt_file () {
        if [ $1 == "user" ]; then
                lookup_file=${quota_passwd}
        else
                lookup_file=${quota_group}
        fi
        while read -r p; do
                IFS=" " read -r id kb_used inode_used <<< $(echo ${p})
                name=$(awk -v id=$id -F ':' '$3 == id {print $1}' ${lookup_file} | head -n 1)
                name=${name:=none}
                echo "lustre_quota,fs=${fs},pool=MDT,${t}=${name},target=${2} kb_used=${kb_used},inode_used=${inode_used}"
        done<"${admin_dir}/${t}_${2}_MDT.txt"
}

for m in ${mdts[@]}
do
        for t in user group project; do
                parse_mdt_file ${t} ${m} &
        done
done

threads=$(ps -ef | grep "lustre_quota_parse" | grep -v grep |  wc -l)
while [ ${threads} -gt 3 ]; do
        sleep 0.2
        threads=$(ps -ef | grep "lustre_quota_parse" | grep -v grep |  wc -l)
done
