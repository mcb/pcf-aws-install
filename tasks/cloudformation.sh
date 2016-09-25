#!/bin/bash

set -e

template=$(ls cloudformation/*cloudformation.json)

params="01NATKeyPair=pcf"
params="$params,05RdsUsername=boshuser"
params="$params,06RdsPassword=boshpass"
params="$params,07SSLCertificateARN=$AWS_SSL_CERTIFICATE_ARN"

aws cloudformation create-stack \
    --stack-name pcf \
    --template-body file://$template \
    --parameters "$params"
