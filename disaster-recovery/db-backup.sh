#!/bin/bash

DB_HOSTNAME=""
DB_NAME=""
DB_PORT=""
DB_USER=""
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE_NAME="$DB_NAME-$TIMESTAMP.sql.gz"
S3_BUCKET_NAME=""

pgdump -h $DB_HOSTNAME -U $DB_USER -p $DB_PORT -d $DB_NAME | gzip > $BACKUP_FILE_NAME

## Copy the gzip file into S3

aws s3 cp $BACKUP_FILE_NAME s3://$S3_BUCKET_NAME
