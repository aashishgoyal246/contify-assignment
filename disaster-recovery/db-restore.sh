#!/bin/bash

DB_HOSTNAME=""
DB_NAME=""
DB_PORT=""
DB_USER=""
S3_BUCKET_NAME=""

# Find the latest backup in S3
LATEST_BACKUP_NAME=$(aws s3 ls s3://$S3_BUCKET_NAME/ | sort | tail -n 1 | awk '{print $4}')

## Copy the gzip file from S3 into local
aws s3 cp s3://$S3_BUCKET_NAME/$LATEST_BACKUP_NAME .

## Create a Database in which you want to restore the data
psql -h $DB_HOSTNAME -U $DB_USER -p $DB_PORT -c "CREATE DATABASE $DB_NAME;"

## Restore the data into the PSQL DB
gunzip -c $LATEST_BACKUP | pg_restore -h $DB_HOSTNAME -U $DB_USER -p $DB_PORT -d $DB_NAME
