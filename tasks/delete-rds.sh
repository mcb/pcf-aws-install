#!/bin/bash

set -e -x

instances=$(aws rds describe-db-instances)

instanceId=$(echo $instances | jq -r ".DBInstances[] | select(.Endpoint.Address == \"$rdsAddress\") | .DBInstanceIdentifier")

aws rds delete-db-instance --skip-final-snapshot --db-instance-identifier $instanceId

aws rds wait db-instance-deleted --db-instance-identifier $instanceId
