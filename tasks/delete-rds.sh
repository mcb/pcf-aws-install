#!/bin/bash

set -e -x

stackname=$AWS_CLOUDFORMATION_STACK_NAME

rdsAddress=$(aws cloudformation describe-stacks --stack-name $stackname | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfRdsAddress") | .OutputValue')

instanceId=$(aws rds describe-db-instances | jq -r ".DBInstances[] | select(.Endpoint.Address == \"$rdsAddress\") | .DBInstanceIdentifier")

aws rds delete-db-instance --skip-final-snapshot --db-instance-identifier $instanceId

aws rds wait db-instance-deleted --db-instance-identifier $instanceId
