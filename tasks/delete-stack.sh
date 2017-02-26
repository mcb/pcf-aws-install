#!/bin/bash

set -e -x

stackname=$AWS_CLOUDFORMATION_STACK_NAME
hostedZoneId=$AWS_HOSTED_ZONE_ID
opsmanDomain=$OPS_MANAGER_DOMAIN

# Grab the AWS Cloud Formation stack info
stack=$(aws cloudformation describe-stacks --stack-name $stackname)

# Delete Route 53 Record Sets

recordSets=$(aws route53 list-resource-record-sets --hosted-zone-id $hostedZoneId)

## Delete Ops Manager Record Set
recordSet=$(echo $recordSets | jq -r --arg domain "$opsmanDomain." '.ResourceRecordSets[] | select(.Name == $domain and .Type == "A")')
publicIp=$(echo $recordSet | jq -r '.ResourceRecords[0].Value')

cat <<EOF >change-resource-record-sets.json
{
  "Comment": "delete record set for opsmanager",
  "Changes": [
    {
      "Action": "DELETE",
      "ResourceRecordSet": $recordSet
    }
  ]
}
EOF

changeRecordSet=$(aws route53 change-resource-record-sets --hosted-zone-id $hostedZoneId --change-batch file://change-resource-record-sets.json)
changeId=$(echo $changeRecordSet | jq -r '.ChangeInfo.Id')

aws route53 wait resource-record-sets-changed --id $changeId

##  Disassociate/Release Ops Manager elasticIp

address=$(aws ec2 describe-addresses | jq -r --arg publicIp $publicIp '.Addresses[] | select(.PublicIp == $publicIp)')

associationId=$(echo $address | jq -r '.AssociationId')
allocationId=$(echo $address | jq -r '.AllocationId')
instanceId=$(echo $address | jq -r '.InstanceId')

aws ec2 disassociate-address --association-id $associationId
aws ec2 release-address --allocation-id $allocationId

# Terminate all EC2 instances

vpcId=$(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfVpc") | .OutputValue')

instanceIds=$(aws ec2 describe-instances --filters Name=vpc-id,Values=$vpcId | jq -r .Reservations[].Instances[].InstanceId)

aws ec2 terminate-instances --instance-ids $instances
aws ec2 wait instance-terminated --instance-ids $instanceIds

# Delete stack

aws cloudformation delete-stack --stack-name $stackname
aws cloudformation wait stack-delete-complete --stack-name $stackname
