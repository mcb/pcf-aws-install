#!/bin/bash

set -e -x

template=$(ls cloudformation/*cloudformation.json)

stackname=pcf

params="ParameterKey=01NATKeyPair,ParameterValue=pcf"
params="$params ParameterKey=05RdsUsername,ParameterValue=boshuser"
params="$params ParameterKey=06RdsPassword,ParameterValue=boshpass"
params="$params ParameterKey=07SSLCertificateARN,ParameterValue=$AWS_SSL_CERTIFICATE_ARN"

aws cloudformation create-stack \
    --stack-name $stackname \
    --template-body file://$template \
    --capabilities CAPABILITY_IAM \
    --parameters $params

aws cloudformation wait stack-create-complete --stack-name $stackname
