#!/bin/bash

set -e -x

source $(dirname $0)/common.sh

stackname=$AWS_CLOUDFORMATION_STACK_NAME
opsmanAmi=$OPS_MANAGER_AMI
keyName=$AWS_KEY_NAME

stack=$(aws cloudformation describe-stacks --stack-name $stackname)

opsmanSubnetId=$(get_output_value PcfPublicSubnetId $stack)
opsmanSgId=$(get_output_value PcfOpsManagerSecurityGroupId $stack)

ec2Instance=$(aws ec2 run-instances \
  --image-id $opsmanAmi \
  --count 1 \
  --instance-type m3.large \
  --key-name $keyName \
  --security-group-ids $opsmanSgId \
  --subnet-id $opsmanSubnetId \
  --associate-public-ip-address \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":100,"VolumeType":"gp2"}}]')

aws ec2 create-tags --resources $(echo $ec2Instance | jq -r ".Instances[0].InstanceId") --tags "Key=Name,Value=Ops Manager"

---

rdsAddress=$(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfRdsAddress") | .OutputValue')

dbInstances=$(aws rds describe-db-instances)
dbInstanceId=$(echo $dbInstances | jq -r ".DBInstances[] | select(.Endpoint.Address == \"$rdsAddress\") | .DBInstanceIdentifier")

aws rds delete-db-instance --skip-final-snapshot --db-instance-identifier $dbInstanceId

aws rds wait db-instance-deleted --db-instance-identifier $dbInstanceId
