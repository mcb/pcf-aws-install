#!/bin/bash

set -e -x

stackname=$AWS_CLOUDFORMATION_STACK_NAME
opsmanAmi=$OPS_MANAGER_AMI
opsmanDomain=$OPS_MANAGER_DOMAIN
adminUser=$OPS_MANAGER_ADMIN_USER
adminPass=$OPS_MANAGER_ADMIN_PASS
decryptPassphrase=$OPS_MANAGER_DECRYPT_PASSPHRASE
keyName=$AWS_KEY_NAME
hostedZoneId=$AWS_HOSTED_ZONE_ID

stack=$(aws cloudformation describe-stacks --stack-name $stackname)

opsmanSgId=$(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfOpsManagerSecurityGroupId") | .OutputValue')
opsmanSubnetId=$(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfPublicSubnetId") | .OutputValue')

ec2Instance=$(aws ec2 run-instances \
  --image-id $opsmanAmi \
  --count 1 \
  --instance-type m3.large \
  --key-name $keyName \
  --security-group-ids $opsmanSgId \
  --subnet-id $opsmanSubnetId \
  --associate-public-ip-address \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":100,"VolumeType":"gp2"}}]')

ec2InstanceId=$(echo $ec2Instance | jq -r ".Instances[0].InstanceId")

aws ec2 create-tags --resources $ec2InstanceId --tags "Key=Name,Value=Ops Manager"

aws ec2 wait instance-status-ok --instance-ids $ec2InstanceId

allocateAddress=$(aws ec2 allocate-address --domain vpc)

allocationId=$(echo $allocateAddress | jq -r '.AllocationId')
publicId=$(echo $allocateAddress | jq -r '.PublicIp')

aws ec2 associate-address --instance-id $ec2InstanceId --allocation-id $allocationId

cat <<EOF >change-resource-record-sets.json
{
  "Comment": "create record set for opsmanager",
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "$opsmanDomain",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "$publicId"
          }
        ]
      }
    }
  ]
}
EOF

createRecordSet=$(aws route53 change-resource-record-sets --hosted-zone-id $hostedZoneId --change-batch file://change-resource-record-sets.json)

changeId=$(echo $createRecordSet | jq -r '.ChangeInfo.Id')

aws route53 wait resource-record-sets-changed --id $changeId

# setup ops manager identity provider

setup=$(jq -n \
--arg decryptPassphrase $decryptPassphrase \
--arg adminUser $adminUser \
--arg adminPass $adminPass \
'{
  setup: {
    decryption_passphrase: $decryptPassphrase,
    decryption_passphrase_confirmation: $decryptPassphrase,
    eula_accepted: "true",
    identity_provider: "internal",
    admin_user_name: $adminUser,
    admin_password: $adminPass,
    admin_password_confirmation: $adminPass,
  }
}')

curl "https://$opsmanDomain/api/v0/setup" -k \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$setup"

# TODO: figure out a better way to poll for availability
# https://opsmgr.anvil.pcfdemo.com/login/ensure_availability
sleep 75
