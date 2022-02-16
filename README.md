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

## Lustre lfs disk check
Checks the fill of all the OSTs and MDTs to ensure their usage is remaining balanced and within an acceptable level of fill.  Also it checks to make sure all OSTs and MDTs are in an "ACTIVE" state.  This needs to be run from a client that mounts the file system.  We run this check from our storage service nodes. 

## Lustre Client Health
This check is run on all Lustre clients to verify that they have mount and can ping the MGS with lctl ping. It also can check and record time to ls and stat certain path(s) and file(s) on the file system to test responsiveness of the mount.  You many not want that check on clients depending on your preferences, it can be commented out if desired.  If used, allow the telegraf user to use sudo to run: lctl ping 

## Lustre Client Performance
This pulls out client performance counters from obdfilter in /proc.  This allows us to track each client's performance on a per MDT/OST level for fine grained workload analysis. This script sources the path to a map file that has a mapping of IP addresses to hostnames (one mapping per line, space separated).  This allows metrics to be tagged with FQDNs for ease of analysis.  The generation of that map file is left up to the site as different environments will have different needs and constraints.  Run this on all MDS and OSS machines.  

## LNET Stats
Parses stats on LNET routers and sends them to InfluxDB; helpful for tracking performance and errors on LNET router nodes

## Lustre Quota Parse
