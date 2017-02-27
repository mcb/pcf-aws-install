#!/bin/bash

set -e -x

opsmanDomain=$OPS_MANAGER_DOMAIN
sshKey=$AWS_SSH_PRIVATE_KEY

cat <<EOF > stop.sh
#!/bin/bash

shopt -s expand_aliases

alias bosh='BUNDLE_GEMFILE=/home/tempest-web/tempest/web/vendor/bosh/Gemfile bundle exec bosh'
alias uaac='BUNDLE_GEMFILE=/home/tempest-web/tempest/web/vendor/uaac/Gemfile bundle exec uaac'

adminUser=$OPS_MANAGER_ADMIN_USER
adminPass=$OPS_MANAGER_ADMIN_PASS

printf '%s\n' "$directorUser" "$directorPass" | bosh login 2>/dev/null

EOF
chmod +x stop.sh

echo "$sshKey" > pcf.pem
chmod 400 pcf.pem

scp -i pcf.pem -oStrictHostKeyChecking=no stop.sh ubuntu@$opsmanDomain:.
ssh -i pcf.pem -oStrictHostKeyChecking=no ubuntu@$opsmanDomain ls

echo "done"
