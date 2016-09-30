#!/bin/bash

set -e -x

opsmanDomain=$OPS_MANAGER_DOMAIN
adminUser=$OPS_MANAGER_ADMIN_USER
adminPass=$OPS_MANAGER_ADMIN_PASS

# Login to UAA
uaac target https://$opsmanDomain/uaa --skip-ssl-validation

uaac token owner get opsman $adminUser -p $adminPass -s ''

UAA_ACCESS_TOKEN=$(uaac context admin | grep access_token | sed -e 's/^\s*access_token:\s//')

# Upload elastic-runtime
file=$(ls elastic-runtime/cf-*.pivotal)

curl "https://$opsmanDomain/api/v0/available_products" -k \
    -X POST \
    -H "Authorization: Bearer $UAA_ACCESS_TOKEN" \
    -F "product[file]=@$file"
