#!/bin/bash

set -e -x

opsmanDomain=$OPS_MANAGER_DOMAIN
adminUser=$OPS_MANAGER_ADMIN_USER
adminPass=$OPS_MANAGER_ADMIN_PASS
sshKey=$AWS_SSH_PRIVATE_KEY

jq -n "{
  opsmanDomain: $(echo $opsmanDomain | jq -R .),
  adminUser: $(echo $adminUser | jq -R .),
  adminPass: $(echo $adminPass | jq -R .)
}" > ci.json

echo "$sshKey" > pcf.pem
chmod 400 pcf.pem

scp -i pcf.pem -oStrictHostKeyChecking=no ci.json ubuntu@$opsmanDomain:.
ssh -i pcf.pem -oStrictHostKeyChecking=no ubuntu@$opsmanDomain ls

echo "done"
