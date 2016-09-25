#!/bin/bash

set -e -x

stackname=$AWS_CLOUDFORMATION_STACK_NAME
sslcertarn=$AWS_SSL_CERTIFICATE_ARN
keyName=$AWS_KEY_NAME

template=$(ls cloudformation/*cloudformation.json)

params="ParameterKey=01NATKeyPair,ParameterValue=$keyName"
params="$params ParameterKey=05RdsUsername,ParameterValue=boshuser"
params="$params ParameterKey=06RdsPassword,ParameterValue=boshpass"
params="$params ParameterKey=07SSLCertificateARN,ParameterValue=$sslcertarn"

aws cloudformation create-stack \
    --stack-name $stackname \
    --template-body file://$template \
    --capabilities CAPABILITY_IAM \
    --parameters $params

aws cloudformation wait stack-create-complete --stack-name $stackname
