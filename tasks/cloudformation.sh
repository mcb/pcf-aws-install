#!/bin/bash

set -e

template=$(ls cloudformation/*cloudformation.json)

params=
params="$params ParameterKey=01NATKeyPair,ParameterValue=pcf"
params="$params ParameterKey=05RdsUsername,ParameterValue=boshuser"
params="$params ParameterKey=06RdsPassword,ParameterValue=boshpass"
params="$params ParameterKey=07SSLCertificateARN,ParameterValue=$AWS_SSL_CERTIFICATE_ARN"

aws cloudformation create-stack \
    --stack-name pcf \
    --template-body file://$template \
    --parameters "$params"