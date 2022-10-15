#!/bin/bash

source /etc/telegraf/lustre_config

stats_line=$(sudo /usr/sbin/lnetctl stats show | sed 's/:\ /=/' | tail -n +2 | xargs | sed 's/\ /,/g')

echo "lnet_stats,fs=${fs} ${stats_line}"
