sqlplus $MONITOR_DB_USER/$MONITOR_DB_PASSWORD@$MONITOR_DB<<EOF
CREATE TABLE INSTANCES_2STOP_H (
REGION VARCHAR2(400 ),
DISPLAY_NAME VARCHAR2(400 ),
IDENTIFIER VARCHAR2(400 ),
COMPARTMENT_ID VARCHAR2(400 ),
TIME_CREATED VARCHAR2(400 ),
DEFINED_TAGS VARCHAR2(32000)
constraint defined_tags_INSTANCES_2STOP_H_json check(defined_tags is json),
LIFECYCLE_STATE VARCHAR2(400),
FREEFORM_TAGS VARCHAR2(32000)
constraint freeform_tags_INSTANCES_2STOP_H_json check(freeform_tags is json),
TIME_MONITORED VARCHAR2(400 )
) SEGMENT CREATION IMMEDIATE
TABLESPACE USERS ;


CREATE TABLE INSTANCES_2STOP (
REGION VARCHAR2(400 ),
DISPLAY_NAME VARCHAR2(400 ),
IDENTIFIER VARCHAR2(400 ),
COMPARTMENT_ID VARCHAR2(400 ),
TIME_CREATED VARCHAR2(400 ),
DEFINED_TAGS VARCHAR2(32000)
constraint defined_tags_INSTANCES_2STOP_json check(defined_tags is json),
LIFECYCLE_STATE VARCHAR2(400),
FREEFORM_TAGS VARCHAR2(32000)
constraint freeform_tags_INSTANCES_2STOP_json check(freeform_tags is json),
TIME_MONITORED VARCHAR2(400 )
) SEGMENT CREATION IMMEDIATE
TABLESPACE USERS ;
