#!/bin/bash

set -e -x

stackname=$AWS_CLOUDFORMATION_STACK_NAME

aws cloudformation delete-stack --stack-name $stackname

aws cloudformation wait stack-delete-complete --stack-name $stackname
