# Lustre TIG
Telegraf Checks and Grafana Dashboards for Monitoring Lustre with TIG

### Note about community plugin
The Lustre community has already created a Lustre plugin for telegraf, named [Lustre2](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/lustre2).  We leverage this plug in because it is great for getting us all the performance stats we need about Lustre file systems.  

This repo contains additional Lustre-related checks that verify system health, monitor aspects of the file system, as well as ingest quota information for tracking.  
