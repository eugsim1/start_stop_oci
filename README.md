Start / Stop OCI servers

How to use it

In a Linux Server install Ansible.

Follow the documentation from [here](https://docs.oracle.com/en-us/iaas/tools/oci-ansible-collection/4.26.0/installation/index.html) to install /configure OCI Ansible Collections.

Check that all the parameters needed are set up in the file setAPI.env

This section is related to the OCI SDK

```
export OCI_CLI_CONFIG_FILE=
echo $OCI_CLI_CONFIG_FILE
export  OCI_CONFIG_PROFILE=DEFAULT
echo $OCI_CONFIG_PROFILE
export OCI_CONFIG_FILE=
```

This section is related to the database which will host the monitoring tables :

```
export MONITOR_DB_USER=
export MONITOR_DB_PASSWORD=
export MONITOR_DB=
```

Create a Database user in this database ( the version can be from 19c to 23c) as :

```
CREATE USER OCIMONITOR IDENTIFIED BY  .... ACCOUNT UNLOCK;
GRANT CONNECT, RESOURCE TO OCIMONITOR;
ALTER USER "OCIMONITOR"
DEFAULT TABLESPACE "USERS"
TEMPORARY TABLESPACE "TEMP";
ALTER USER "OCIMONITOR" QUOTA UNLIMITED ON "USERS";
ALTER USER "OCIMONITOR" DEFAULT ROLE "CONNECT","RESOURCE";
```

Execute the script create_sql_tables.sh to create the tables to the Oracle Database.

Execute the script create_regions.sh to create the regions of your tenancy

```
![tags](X:\oci4cc4\start_stop_oci\images\tags.gif)source  setAPI.env

mkdir -vp configuration_data
ansible-playbook  01-regions.yaml

### delete last line

sed -r '/^\s*$/d' -i configuration_data/regions_form.csv 
cat                  configuration_data/regions_form.csv 
```

 Before to execute the script stop_daily_.sh check that all the variables are setup correctly 

The database will store in regular intervals the content of the Ansible call to the OCI services.
 
 In our case we want to manage ALL OCI servers in the tenancy.
 We will implement a “forced stop” at XX.00 and we will restard them if needed at XX.00 time ( the time is always the time from the compute node) 

For this purpose the servers should be tagged with some mandatory tags as.
 these tags in our implementation are free_form tags
 RunAlways
 RunDuringWorkingHours
 DelateAfterDate
 
 in the below picture the server will run ALWAYS without interruption ,

If the user wants to run his server only during normal working hours ( 08.00 CET up to 22.00 CET) then the settings should be :
 RunAlways = ‘No’
 RunDuringWorkingHours=’Yes’


Tag your instances to be managed by the cron job as :

![](/images/tags.gif)

The cron entry for this setting is :

```
0 22 * * * /XXXX/stop_daily.sh
```



```
### BASE the installation directory of these scripts
### 
source $BASE/setAPI

mkdir -vp data/2stop

date_now=$(date +%m-%d-%y-%H-%M)
zip  data/2stop/all_region_${date_now}.zip -m data/2stop/*


### this is where you have generated the region file
###
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

 

### delete empty files generated from the previous ansible call
cd data/2stop
for files in "*.csv"
do
  sed -r '/^\s*$/d' -i $files
done

find .  -name "*.csv" -type f -empty  -delete
cat *.csv > data/2stop/all_instances_2stop_tenancy.csv
rm -rf all_region_*.csv


########### load data to database
########### the table instance_2stop_h will contain historical data

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

export DATA_FILE=data/2stop/all_instances_2stop_tenancy.csv

sed 's/FILE_DATA/$DATA_FILE/g' -i data/2stop/create_ctl_instances_2stop_file.ctl

sqlldr $MONITOR_DB_USER/$MONITOR_DB_PASSWORD@$MONITOR_DB CONTROL=data/2stop/create_ctl_instances_2stop_file.ctl \
bad=data/2stop/Computes_nodes_${date_now}.bad \
log=data/2stop/Computes_nodes_${date_now}.log



### get from the database the servers to stop
## lifecycle_state='RUNNING' and FREEFORM_TAGS.RunAlways No
##
## your servers should have already the freefrom Tag configured

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
```

