#!/bin/bash

set -e -x

hostedZoneId=$AWS_HOSTED_ZONE_ID
opsmanDomain=$OPS_MANAGER_DOMAIN

recordSets=$(aws route53 list-resource-record-sets --hosted-zone-id $hostedZoneId)

recordSet=$(echo $recordSets | jq -r --arg domain "$opsmanDomain." '.ResourceRecordSets[] | select(.Name == $domain and .Type == "A")')

publicIp=$(echo $recordSet | jq -r '.ResourceRecords[0].Value')

# Delete the record set
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

# Disassociate and release the elasticIp

address=$(aws ec2 describe-addresses | jq -r --arg publicIp $publicIp '.Addresses[] | select(.PublicIp == $publicIp)')

associationId=$(echo $address | jq -r '.AssociationId')
instanceId=$(echo $address | jq -r '.InstanceId')

aws ec2 disassociate-address --association-id $associationId

# Terminate the EC2 instance

aws ec2 terminate-instances --instance-ids $instanceId

aws ec2 wait instance-terminated $instancdId
