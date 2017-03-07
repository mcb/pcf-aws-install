#!/bin/bash

set -e -x

opsmanDomain=$OPS_MANAGER_DOMAIN
adminUser=$OPS_MANAGER_ADMIN_USER
adminPass=$OPS_MANAGER_ADMIN_PASS
stackname=$AWS_CLOUDFORMATION_STACK_NAME
keyName=$AWS_KEY_NAME
sshPrivateKey=$AWS_SSH_PRIVATE_KEY
region=$AWS_DEFAULT_REGION
ntpServers=$NTP_SERVERS
s3endpoint=$S3_ENDPOINT

# login to UAA and get the access token
uaac target https://$opsmanDomain/uaa --skip-ssl-validation
uaac token owner get opsman $adminUser -p $adminPass -s ''
UAA_ACCESS_TOKEN=$(uaac context admin | grep access_token | awk '{ print $2 }')

# Grab the AWS Cloud Formation stack info
stack=$(aws cloudformation describe-stacks --stack-name $stackname)

# Configure AWS Config, Director Config, Security

accessKeyId=$(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfIamUserAccessKey") | .OutputValue')
secretAccessKey=$(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfIamUserSecretAccessKey") | .OutputValue')
vpcId=$(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfVpc") | .OutputValue')
vmsSecurityGroupId=$(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfVmsSecurityGroupId") | .OutputValue')
s3bucketOpsManager=$(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfOpsManagerS3Bucket") | .OutputValue')

# AWS Config

iaasConfiguration=$(jq -n \
--arg accessKeyId "$accessKeyId" \
--arg secretAccessKey "$secretAccessKey" \
--arg vpcId "$vpcId" \
--arg vmsSecurityGroupId "$vmsSecurityGroupId" \
--arg keyName "$keyName" \
--arg sshPrivateKey "$sshPrivateKey" \
--arg region "$region" \
'{
  iaas_configuration: {
    access_key_id: $accessKeyId,
    secret_access_key: $secretAccessKey,
    vpc_id: $vpcId,
    security_group: $vmsSecurityGroupId,
    key_pair_name: $keyName,
    ssh_private_key: $sshPrivateKey,
    region: $region
  }
}')

curl "https://$opsmanDomain/api/v0/staged/director/properties" -k \
    -X PUT \
    -H "Authorization: Bearer $UAA_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$iaasConfiguration"

# Director Config

directorConfiguration=$(jq -n \
--arg ntpServers "$ntpServers" \
--arg s3endpoint "$s3endpoint" \
--arg s3bucketOpsManager "$s3bucketOpsManager" \
--arg accessKeyId "$accessKeyId" \
--arg secretAccessKey "$secretAccessKey" \
'{
  director_configuration: {
    ntp_servers_string: $ntpServers,
    resurrector_enabled: true,
    post_deploy_enabled: true,
    database_type: "internal",
    blobstore_type: "s3",
    s3_blobstore_options: {
      endpoint: $s3endpoint,
      bucket_name: $s3bucketOpsManager,
      access_key: $accessKeyId,
      secret_key: $secretAccessKey,
      signature_version: 2
    }
  }
}')

# revert to internal because s3 endpoint configuration doesn't work yet...
directorConfiguration=$(echo $directorConfiguration | jq -r '.director_configuration.blobstore_type = "local" | del(.director_configuration.s3_blobstore_options)')

curl "https://$opsmanDomain/api/v0/staged/director/properties" -k \
    -X PUT \
    -H "Authorization: Bearer $UAA_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$directorConfiguration"

# Configure "Create Availability Zones"

az1=$(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfPrivateSubnetAvailabilityZone") | .OutputValue')

availabilityZones=$(jq -n \
--arg az1 $az1 \
'{
  availability_zones: [{
    name: $az1
  }]
}')

curl "https://$opsmanDomain/api/v0/staged/director/availability_zones" -k \
    -X PUT \
    -H "Authorization: Bearer $UAA_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$availabilityZones"

# Configure "Create Networks"

vpcSubnetId=$(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfPrivateSubnetId") | .OutputValue')

networks=$(jq -n \
--arg vpcSubnetId $vpcSubnetId \
--arg az1 $az1 \
'{
  icmp_checks_enabled: false,
  networks: [{
    name: "pcf-network",
    service_network: false,
    subnets: [{
      iaas_identifier: $vpcSubnetId,
      cidr: "10.0.16.0/20",
      reserved_ip_ranges: "10.0.16.1-10.0.16.9",
      dns: "10.0.0.2",
      gateway: "10.0.16.1",
      availability_zone_names: [$az1]
    }]
  }]
}')

curl "https://$opsmanDomain/api/v0/staged/director/networks" -k \
    -X PUT \
    -H "Authorization: Bearer $UAA_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$networks"

# Configure "Assign AZs and Networks"

networkAndAz=$(jq -n \
--arg az1 $az1 \
'{
    networks_and_azs: {
      network: {
        name: "pcf-network"
      },
      singleton_availability_zone: {
        name: $az1
      }
    }
}')

curl "https://$opsmanDomain/api/v0/staged/director/network_and_az" -k \
    -X PUT \
    -H "Authorization: Bearer $UAA_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$networkAndAz"

# Apply Changes

curl "https://$opsmanDomain/api/v0/installations" -k \
    -X POST \
    -H "Authorization: Bearer $UAA_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{}"
