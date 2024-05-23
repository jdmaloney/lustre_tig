# Lustre TIG
Telegraf Checks and Grafana Dashboards for Monitoring DDN's Exascaler Lustre product with TIG

### Note about community plugin
The Lustre community has already created a Lustre plugin for telegraf, named [Lustre2](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/lustre2).   We leverage this plugin because it is great for getting us all the performance stats we need about Lustre file systems from the server side.  

This repo contains additional Lustre-related checks that verify system health, monitor state/optimization of the file system, per-client performance, as well as ingest user/group/project quota information for tracking. 

## Lustre HA Health
Monitors the status of HA in the Exascaler product so we know if a component loses its HA health and we can be alerted to it happening. This is run from the MDS(s) as it is not needed to be run on all nodes.   

## Lustre Mount Count
Tracks the number of clients with mount of the file system.  For most accurate results run this on the MDS(s).   

## Lustre Server Mount
Checks the health of MGT/MDT/OST mounts on the MGS/MDS/OSS machines respectively so we get alerted if mount is lost for one or more of those devices on one or more servers.

## EMF Perf Ping
Leverages the built in ExaScaler ping verification tool to ensure that all interfaces on all stacks are healthy and not in a failed state.  

## Lustre lfs disk check
Checks the fill of all the OSTs and MDTs to ensure their usage is remaining balanced and within an acceptable level of fill.  Also it checks to make sure all OSTs and MDTs are in an "ACTIVE" state.  This needs to be run from a client that mounts the file system.  We run this check from our storage service nodes. 

## Lustre Client Health
This check is run on all Lustre clients to verify that they have mount and can ping the MGS with lctl ping. It also can check and record time to ls and stat certain path(s) and file(s) on the file system to test responsiveness of the mount.  You many not want that check on clients depending on your preferences, it can be commented out if desired.  If used, allow the telegraf user to use sudo to run: lctl ping 

## Lustre Client Performance
This pulls out client performance counters from obdfilter in /proc.  This allows us to track each client's performance on a per MDT/OST level for fine grained workload analysis. This script sources the path to a map file that has a mapping of IP addresses to hostnames (one mapping per line, space separated).  This allows metrics to be tagged with FQDNs for ease of analysis.  The generation of that map file is left up to the site as different environments will have different needs and constraints.  Run this on all MDS and OSS machines.  

NOTE: The community lustre2 plugin for telegraf now can extract data from these counters (as of v.1.23) however it won't translate the IP addresses to hostnames which this check does.  If that translation is not needed; feel free to use the community check.

## Lustre Changelog Check
This pulls in stats about the state of changelog consumption for the cl1 consumer on each MDT on a system.  It gathers how many records are in the "backlog" to be ingested by the consumer, how large the change log is on each MDT, and the current indexes of both the MDT and the consumer.  This is helpful to make sure Robinhood (or any consumer) is keeping up with change logs and not ballooning the space change logs take up on the MDT.  

## LNET Stats
Parses stats on LNET routers and sends them to InfluxDB; helpful for tracking performance and errors on LNET router nodes

## Lustre Quota Parse & Lustre Quota ID Dump
Parses quota output for user, group, and project quotas for storing in InfluxDB.

#### Quota Dump
Run this on all Lustre servers.  The check dumps all quota data on a per-OST/MDT basis and formats it for quick parsing on a central machine that runs the Quota Parse script descripted below.  This check doesn't acctually ship any data to the database, it puts files in the shared admin directory that also must contain a file called pool_map.  The pool_map file has two columns, one for the name of the pool and the second for the name of the target as it appears in /proc/fs/lustre/osd-ldiskfs/.  Note for MDTs it is mandatory that their pool name be "all".  Additionally this check verifies that quota enforcement is configured as expected on all targets.

#### Quota Parse
We run this from our Lustre Admin node, but it can be run on any client that has access to the shared admin directory defined in lustre_config which contains the pool_map file and the raw quota dump files.  The check takes the dumped and formatted raw quota data and parses it; gathering data per user/group/project as well as bytes per OST pool and files per MDT.   This information is then shipped to the database.  We generally run this on a 15 minute interval but adjust to what is tolerable in your environment.   

## Lustre Robinhood Quota
The check is specifically applicable if your are running Robinhood against your Lustre FS *and* you are running a version of Robinhood that supports Project ID ingestion (which requires a custom Robinhood build as of March 2023).  This check pulls in per-user and per-group usage on a per-project basis so you can see who/what group is using space inside a project quota on Lustre.  Also it gives you per-user/per-group per-project file size histogram data, per-project file size histogram data, and per-FS file size histogram data.

## Lustre Robinhood Stats
This check gathers statistics from a running Robinhood daemon by parsing its log (at its default location /var/log/robinhood.log, if you have a different path, update the single time that path is referenced in the check).  This gives a whole host of information about how the Robinhood daemon is performing and it supports multiple MDT changelog consumption "out of the box".  
