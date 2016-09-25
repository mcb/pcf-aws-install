#!/bin/bash

set -e -x

stackname=pcf

aws cloudformation delete-stack --stack-name $stackname

aws cloudformation wait stack-delete-complete --stack-name $stackname
