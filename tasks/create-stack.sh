#!/bin/bash

set -e -x

params="ParameterKey=01NATKeyPair,ParameterValue=$AWS_KEY_NAME"
params="$params ParameterKey=04RdsDBName,ParameterValue=$RDS_DBNAME"
params="$params ParameterKey=05RdsUsername,ParameterValue=$RDS_USERNAME"
params="$params ParameterKey=06RdsPassword,ParameterValue=$RDS_PASSWORD"
params="$params ParameterKey=07SSLCertificateARN,ParameterValue=$AWS_SSL_CERTIFICATE_ARN"

cloudformation=$(ls cloudformation/*cloudformation.json)
template=template.json

if [ -z $RDS_DBNAME ] && [ -z $RDS_USERNAME ] && [ -z $RDS_PASSWORD ]; then
  cat $cloudformation |
    jq -r ' .Parameters."04RdsDBName".MinLength = 0
          | .Parameters."06RdsPassword".MinLength = 0
          | del(.Outputs.PcfRdsDBName)
          | del(.Outputs.PcfRdsPassword)
          | del(.Outputs.PcfRdsUsername)
          | del(.Outputs.PcfRdsPort)
          | del(.Outputs.PcfRdsAddress)' \
          > $template
else
  $template=$cloudformation
fi

aws cloudformation create-stack \
    --stack-name $AWS_CLOUDFORMATION_STACK_NAME \
    --template-body file://$template \
    --capabilities CAPABILITY_IAM \
    --parameters $params

aws cloudformation wait stack-create-complete --stack-name $AWS_CLOUDFORMATION_STACK_NAME
