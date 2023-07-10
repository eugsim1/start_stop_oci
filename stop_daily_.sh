source $BASE/setAPI

 

date_now=$(date +%m-%d-%y-%H-%M)
zip data/2stop/all_region_${date_now}.zip -m data/2stop/*



input=configuration_data/regions_form.csv
while IFS= read -r line
do
ansible-playbook  01-search_instancesv1-stop.yaml \
--extra-vars "region=$line"  \
--extra-vars "date_monitored=$date_now"  \
--extra-vars "dest=data/2stop"  \
--tags run-instance \
--tags dbg-instance \
--tags write-instance-raw-csv
done<$input

 
 
### delete empty files
cd data/2stop
for files in "*.csv"
do
  sed -r '/^\s*$/d' -i $files
done


find .  -name "*.csv" -type f -empty  -delete
cat *.csv > data/2stop/all_instances_2stop_tenancy.csv
rm -rf all_region_*.csv



########### load data to database

sqlplus -s $MONITOR_DB_USER/$MONITOR_DB_PASSWORD@$MONITOR_DB<<EOF
insert into   instances_2stop_h select * from instances_2stop;
commit;
exit;
EOF


sqlplus -s $MONITOR_DB_USER/$MONITOR_DB_PASSWORD@$MONITOR_DB<<EOF
truncate table  instances_2stop drop storage;
commit;
exit;
EOF



cat<<-EOF>data/2stop/create_ctl_instances_2stop_file.ctl

load data
infile  "FILE_DATA"
truncate into table  INSTANCES_2STOP
fields terminated by "|"  
( 
region,
display_name,
identifier,
compartment_id,
time_created,
defined_tags char(32000),
lifecycle_state "upper(:lifecycle_state)",
freeform_tags char(32000), 
time_monitored)

EOF

export DATA_FILE=data/2stop/instances_2stop_weekend.db

sed 's/FILE_DATA/$DATA_FILE/g' -i data/2stop/create_ctl_instances_2stop_file.ctl

data/2stop/create_ctl_instances_2stop_file.ctl data/2stop/Compute_nodes.ctl

sqlldr $MONITOR_DB_USER/$MONITOR_DB_PASSWORD@$MONITOR_DB CONTROL=data/2stop/Compute_nodes.ctl \
bad=data/2stop/Computes_nodes_${date_rep}.bad \
log=data/2stop/Computes_nodes_${date_rep}.log



### get from the database the servers to stop
## lifecycle_state='RUNNING' and FREEFORM_TAGS.RunAlways No
##
sqlplus -s $MONITOR_DB_USER/$MONITOR_DB_PASSWORD@$MONITOR_DB<<EOF>data/2stop/instances_2stp_sql.txt
SET HEADING OFF;
SET LINESIZE 120;
SET FEEDBACK OFF;
set markup csv on delimi '|' quote off;
select ins.region, ins.identifier,ins.compartment_id,ins.display_name,   ins.FREEFORM_TAGS.RunAlways from INSTANCES_2STOP ins
where ins.lifecycle_state='RUNNING' and upper(ins.FREEFORM_TAGS.RunAlways)='NO';
exit;
EOF




ansible-playbook  01-stop-instance.yaml \
--extra-vars="action=stop"  \
--extra-vars="instance_2stop=data/2stop/instances_2stp_sql.txt"

