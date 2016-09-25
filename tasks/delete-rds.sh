#!/bin/bash

set -e -x

stackname=$AWS_CLOUDFORMATION_STACK_NAME

stack=$(aws cloudformation describe-stacks --stack-name $stackname)
rdsAddress=$(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfRdsAddress") | .OutputValue')

dbInstances=$(aws rds describe-db-instances)
dbInstanceId=$(echo $dbInstances | jq -r ".DBInstances[] | select(.Endpoint.Address == \"$rdsAddress\") | .DBInstanceIdentifier")

aws rds delete-db-instance --skip-final-snapshot --db-instance-identifier $dbInstanceId

aws rds wait db-instance-deleted --db-instance-identifier $dbInstanceId
