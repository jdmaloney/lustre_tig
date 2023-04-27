#!/bin/bash

date_grep=$(date +"%Y/%m/%d %H:%M" -d "1 minute ago")
tfile=$(mktemp /tmp/rbhstat.XXXXXXX)
tfile2=$(mktemp /tmp/rbhstat.XXXXXXX)

grep "${date_grep}" /var/log/robinhood.log > "${tfile}"

if [ $(cat "${tfile}" | wc -l) -eq 0 ]; then
	rm -rf "${tfile}" "${tfile2}"
	exit 0
fi

readers=($(cat ${tfile} | grep "ChangeLog reader" | cut -d'#' -f 2 | cut -d':' -f 1))

for r in ${readers[@]}
do
	cat "${tfile}" | grep -A21 "ChangeLog reader #${r}" > "${tfile2}"
	IFS=" " read fs_name mdt_name reader_id records_read interesting_records suppressed_records <<< "$(cat "${tfile2}" | head -n 7 | tail -n +2 | cut -d'=' -f 2- | xargs)"
	IFS=" " read receive_speed receive_ratio pushed_speed pushed_ratio commit_speed commit_ratio clear_speed clear_ratio <<< "$(cat "${tfile2}" | grep speed | cut -d' ' -f 13- | tr -d -c 0-9:. | sed 's/:/\ /g')"
	IFS=" " read mark create mkdir hlink slink mknod unlink rmdir rename rnmto open close layout trunc setattr xattr hsm mtime ctime atime migrate flrw resync gxatr nopen <<< "$(cat "${tfile2}" | grep -A3 MARK | cut -d' ' -f 9- | sed "s/$/,/g" | tr -d -c 0-9, | sed 's/,/\ /g')"
	echo "robinhood_reader_stats,fs_name=${fs_name},mdt_name=${mdt_name},reader_id=${reader_id} records_read=${records_read},interesting_records=${interesting_records},suppressed_records=${suppressed_records},receive_speed=${receive_speed},receive_ratio=${receive_ratio},pushed_speed=${pushed_speed},pushed_ratio=${pushed_ratio},commit_speed=${commit_speed},commit_ratio=${commit_ratio},clear_speed=${clear_speed},clear_ratio=${clear_ratio},mark=${mark},create=${create},mkdir=${mkdir},hlink=${hlink},slink=${slink},mknod=${mknod},unlink=${unlink},rmdir=${rmdir},rename=${rename},rnmto=${rnmto},open=${open},close=${close},layout=${layout},trunc=${trunc},setattr=${setattr},xattr=${xattr},hsm=${hsm},mtime=${mtime},ctime=${ctime},atime=${atime},migrate=${migrate},flrw=${flrw},resync=${resync},gxatr=${gxatr},nopen=${nopen}"
done

## Pipeline Stats
cat "${tfile}" | grep -A12 "EntryProcessor Pipeline Stats" > "${tfile2}"

IFS=" " read GET_FID_wait GET_FID_current GET_FID_done GET_FID_total GET_FID_rate GET_INFO_DB_wait GET_INFO_DB_current GET_INFO_DB_done GET_INFO_DB_total GET_INFO_DB_rate GET_INFO_FS_wait GET_INFO_FS_current GET_INFO_FS_done GET_INFO_FS_total GET_INFO_FS_rate PRE_APPLY_wait PRE_APPLY_current PRE_APPLY_done PRE_APPLY_total PRE_APPLY_rate DB_APPLY_wait DB_APPLY_current DB_APPLY_done DB_APPLY_total DB_APPLY_rate DB_APPLY_percent_batch DB_APPLY_batch_size CHGLOG_CLR_wait CHGLOG_CLR_current CHGLOG_CLR_done CHGLOG_CLR_total CHGLOG_CLR_rate RM_OLD_ENTRIES_wait RM_OLD_ENTRIES_current RM_OLD_ENTRIES_done RM_OLD_ENTRIES_total RM_OLD_ENTRIES_rate <<< "$(cat "${tfile2}" | grep -A12 "EntryProcessor Pipeline Stats" | grep -A7 Stage | tail -n +2 | cut -d':' -f 4- | sed 's/|/,/g' | tr -d -c 0-9.:, | sed 's/,,/,/g' | sed 's/:/,/g' | sed 's/,/\ /g' | cut -c 2-)"
echo "robinhood_pipeline_stats,fs_name=${fs_name} GET_FID_wait=${GET_FID_wait},GET_FID_current=${GET_FID_current},GET_FID_done=${GET_FID_done},GET_FID_total=${GET_FID_total},GET_FID_rate=${GET_FID_rate},GET_INFO_DB_wait=${GET_INFO_DB_wait},GET_INFO_DB_current=${GET_INFO_DB_current},GET_INFO_DB_done=${GET_INFO_DB_done},GET_INFO_DB_total=${GET_INFO_DB_total},GET_INFO_DB_rate=${GET_INFO_DB_rate},GET_INFO_FS_wait=${GET_INFO_FS_wait},GET_INFO_FS_current=${GET_INFO_FS_current},GET_INFO_FS_done=${GET_INFO_FS_done},GET_INFO_FS_total=${GET_INFO_FS_total},GET_INFO_FS_rate=${GET_INFO_FS_rate},PRE_APPLY_wait=${PRE_APPLY_wait},PRE_APPLY_current=${PRE_APPLY_current},PRE_APPLY_done=${PRE_APPLY_done},PRE_APPLY_total=${PRE_APPLY_total},PRE_APPLY_rate=${PRE_APPLY_rate},DB_APPLY_wait=${DB_APPLY_wait},DB_APPLY_current=${DB_APPLY_current},DB_APPLY_done=${DB_APPLY_done},DB_APPLY_total=${DB_APPLY_total},DB_APPLY_rate=${DB_APPLY_rate},DB_APPLY_percent_batch=${DB_APPLY_percent_batch},DB_APPLY_batch_size=${DB_APPLY_batch_size},CHGLOG_CLR_wait=${CHGLOG_CLR_wait},CHGLOG_CLR_current=${CHGLOG_CLR_current},CHGLOG_CLR_done=${CHGLOG_CLR_done},CHGLOG_CLR_total=${CHGLOG_CLR_total},CHGLOG_CLR_rate=${CHGLOG_CLR_rate},RM_OLD_ENTRIES_wait=${RM_OLD_ENTRIES_wait},RM_OLD_ENTRIES_current=${RM_OLD_ENTRIES_current},RM_OLD_ENTRIES_done=${RM_OLD_ENTRIES_done},RM_OLD_ENTRIES_total=${RM_OLD_ENTRIES_total},RM_OLD_ENTRIES_rate=${RM_OLD_ENTRIES_rate}"
IFS=" " read db_ops_get db_ops_insert db_ops_update db_ops_remove <<< "$(cat "${tfile2}" | grep "DB ops" | cut -d' ' -f 8 | tr -d -c 0-9/ | sed 's/\//\ /g')"
echo "robinhood_pipeline_stats,fs_name=${fs_name} db_ops_get=${db_ops_get},db_ops_insert=${db_ops_insert},db_ops_update=${db_ops_update},db_ops_remove=${db_ops_remove}"

rm -rf "${tfile}" "${tfile2}"
