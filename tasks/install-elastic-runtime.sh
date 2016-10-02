#!/bin/bash

set -e -x

stackName=$AWS_CLOUDFORMATION_STACK_NAME
opsmanDomain=$OPS_MANAGER_DOMAIN
adminUser=$OPS_MANAGER_ADMIN_USER
adminPass=$OPS_MANAGER_ADMIN_PASS
systemDomain=$CF_SYSTEM_DOMAIN
appsDomain=$CF_APPS_DOMAIN
cfNotifyEmail=$CF_NOTIFY_EMAIL
cfSmtpFrom=$CF_SMTP_FROM
cfSmtpAddress=$CF_SMTP_ADDRESS
cfSmtpPort=$CF_SMTP_PORT
cfSmtpUsername=$CF_SMTP_USERNAME
cfSmtpPassword=$CF_SMTP_PASSWORD
cfS3Endpoint=$CF_S3_ENDPOINT

# Get AWS Stack Outputs
stack=$(aws cloudformation describe-stacks --stack-name $stackName)

# Login to UAA
uaac target https://$opsmanDomain/uaa --skip-ssl-validation

uaac token owner get opsman $adminUser -p $adminPass -s ''

UAA_ACCESS_TOKEN=$(uaac context admin | grep access_token | sed -e 's/^\s*access_token:\s//')

# Upload elastic-runtime
file=$(ls elastic-runtime/cf-*.pivotal)

# curl "https://$opsmanDomain/api/v0/available_products" -k \
#     -X POST \
#     -H "Authorization: Bearer $UAA_ACCESS_TOKEN" \
#     -F "product[file]=@$file"

# Stage elastic-runtime
availableProducts=$(curl "https://$opsmanDomain/api/v0/available_products" -k \
    -X GET \
    -H "Authorization: Bearer $UAA_ACCESS_TOKEN")

cfVersion=$(echo $availableProducts | jq -r '.[] | select(.name == "cf") | .product_version')

stageData=$(jq -n "{
  name: \"cf\",
  product_version: $(echo $cfVersion | jq -R .)
}")

curl "https://$opsmanDomain/api/v0/staged/products" -k \
    -X POST \
    -H "Authorization: Bearer $UAA_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$stageData"

# Get the guid
stagedProducts=$(curl "https://$opsmanDomain/api/v0/staged/products" -k \
    -X GET \
    -H "Authorization: Bearer $UAA_ACCESS_TOKEN")

cfGuid=$(echo $stagedProducts | jq -r '.[] | select(.type == "cf") | .guid')

# Configure elastic-runtime
properties=$(jq -n "{
  properties: {
    \".cloud_controller.system_domain\": {
      value: $(echo $systemDomain | jq -R .)
    },
    \".cloud_controller.apps_domain\": {
      value: $(echo $appsDomain | jq -R .)
    },
    \".properties.networking_point_of_entry\": {
      value: \"external_non_ssl\"
    },
    \".properties.logger_endpoint_port\": {
      value: \"4443\"
    },
    \".properties.security_acknowledgement\": {
      value: \"X\"
    },
    \".mysql_monitor.recipient_email\": {
      value: $(echo $cfNotifyEmail | jq -R .)
    },
    \".properties.system_blobstore\": {
      value: \"external\"
    },
    \".properties.system_blobstore.external.endpoint\": {
      value: $(echo $cfS3Endpoint | jq -R .)
    },
    \".properties.system_blobstore.external.access_key\": {
      value: $(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfIamUserAccessKey") | .OutputValue' | jq -R .)
    },
    \".properties.system_blobstore.external.secret_key\": {
      value: {
        secret: $(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfIamUserAccessKey") | .OutputValue' | jq -R .)
      }
    },
    \".properties.system_blobstore.external.buildpacks_bucket\": {
      value: $(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfElasticRuntimeS3BuildpacksBucket") | .OutputValue' | jq -R .)
    },
    \".properties.system_blobstore.external.droplets_bucket\": {
      value: $(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfElasticRuntimeS3DropletsBucket") | .OutputValue' | jq -R .)
    },
    \".properties.system_blobstore.external.packages_bucket\": {
      value: $(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfElasticRuntimeS3PackagesBucket") | .OutputValue' | jq -R .)
    },
    \".properties.system_blobstore.external.resources_bucket\": {
      value: $(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfElasticRuntimeS3ResourcesBucket") | .OutputValue' | jq -R .)
    },
    \".properties.smtp_from\": {
      value: $(echo $cfSmtpFrom | jq -R .)
    },
    \".properties.smtp_address\": {
      value: $(echo $cfSmtpAddress | jq -R .)
    },
    \".properties.smtp_port\": {
      value: $(echo $cfSmtpPort | jq -R .)
    },
    \".properties.smtp_credentials\": {
      value: {
        identity: $(echo $cfSmtpUsername | jq -R .),
        password: $(echo $cfSmtpPassword | jq -R .)
      }
    },
    \".properties.smtp_enable_starttls_auto\": {
      value: \"true\"
    }
  }
}")

curl "https://$opsmanDomain/api/v0/staged/products/$cfGuid/properties" -k \
    -X PUT \
    -H "Authorization: Bearer $UAA_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$properties"

# Configure jobs
jobs=$(curl "https://$opsmanDomain/api/v0/staged/products/$cfGuid/jobs" -k \
    -X GET \
    -H "Authorization: Bearer $UAA_ACCESS_TOKEN")

# Configure router job
routerGuid=$(echo $jobs | jq -r '.jobs[] | select(.name == "router") | .guid')

routerConfig=$(curl "https://$opsmanDomain/api/v0/staged/products/$cfGuid/jobs/$routerGuid/resource_config" -k \
    -X GET \
    -H "Authorization: Bearer $UAA_ACCESS_TOKEN")

pcfElbDnsName=$(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfElbDnsName") | .OutputValue')

pcfElbName=$(aws elb describe-load-balancers | jq -r --arg pcfElbDnsName $pcfElbDnsName '.LoadBalancerDescriptions[] | select(.DNSName == $pcfElbDnsName) | .LoadBalancerName')

routerConfigElb=$(echo $routerConfig | jq -r --arg pcfElbName $pcfElbName '.elb_names = [ $pcfElbName ]')

curl "https://$opsmanDomain/api/v0/staged/products/$cfGuid/jobs/$routerGuid/resource_config" -k \
    -X PUT \
    -H "Authorization: Bearer $UAA_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$routerConfigElb"

# Configure Diego Brain elb
pcfElbSshDns=$(echo $stack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PcfElbSshDnsName") | .OutputValue')

pcfElbSshName=$(aws elb describe-load-balancers | jq -r --arg pcfElbSshDns $pcfElbSshDns '.LoadBalancerDescriptions[] | select(.DNSName == $pcfElbSshDns) | .LoadBalancerName')

diegoBrainGuid=$(echo $jobs | jq -r '.jobs[] | select(.name == "diego_brain") | .guid')

diegoBrainConfig=$(curl "https://$opsmanDomain/api/v0/staged/products/$cfGuid/jobs/$diegoBrainGuid/resource_config" -k \
    -X GET \
    -H "Authorization: Bearer $UAA_ACCESS_TOKEN")

diegoBrainConfigWithElb=$(echo $diegoBrainConfig | jq -r --arg pcfElbSshName $pcfElbSshName '.elb_names = [ $pcfElbSshName ]')

curl "https://$opsmanDomain/api/v0/staged/products/$cfGuid/jobs/$diegoBrainGuid/resource_config" -k \
    -X PUT \
    -H "Authorization: Bearer $UAA_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$diegoBrainConfigWithElb"

# Upload stemcell
stemcell=$(ls stemcell/*.tgz)

curl "https://$opsmanDomain/api/v0/stemcells" -k \
    -X POST \
    -H "Authorization: Bearer $UAA_ACCESS_TOKEN" \
    -F "stemcell[file]=@$stemcell"

# Apply Changes
# pendingChanges=$(curl "https://$opsmanDomain/api/v0/staged/pending_changes" -k \
#     -X GET \
#     -H "Authorization: Bearer $UAA_ACCESS_TOKEN")
