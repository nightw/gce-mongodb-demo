#!/bin/bash

set -euf -o pipefail

cd /tmp

# Installing release package if needed
if ! dpkg --get-selections puppetlabs-release-pc1 | grep -q 'install'; then
  wget https://apt.puppetlabs.com/puppetlabs-release-pc1-xenial.deb
  dpkg -i puppetlabs-release-pc1-xenial.deb
  rm puppetlabs-release-pc1-xenial.deb
fi

# Installing puppet agent if needed
if ! dpkg --get-selections puppet-agent | grep -q 'install'; then
  apt-get update
  apt-get install -y puppet-agent
fi

# Installing git if needed
if ! dpkg --get-selections git | grep -q 'install'; then
  apt-get update
  apt-get install -y git
fi

# Now install puppet modules if needed
if ! test -d '/etc/puppetlabs/code/environments/production/modules/ntp'; then
  /opt/puppetlabs/bin/puppet module install puppetlabs-ntp --version 6.0.0
fi
if ! test -d '/etc/puppetlabs/code/environments/production/modules/puppet'; then
  /opt/puppetlabs/bin/puppet module install theforeman-puppet --version 7.0.0
fi

# Now get the puppet server code from this project publicly via HTTPS from GitHub and run it if needed
if ! dpkg --get-selections | grep -q 'puppetserver.*install'; then
  mkdir -p gce_mongodb_test_puppet_server/manifests
  wget -O gce_mongodb_test_puppet_server/manifests/puppet_server_base.pp https://raw.githubusercontent.com/nightw/gce-mongodb-demo/master/modules/gce_mongodb_test_puppet_server/manifests/puppet_server_base.pp
  /opt/puppetlabs/bin/puppet apply --modulepath=/tmp:/etc/puppetlabs/code/environments/production/modules -e 'include gce_mongodb_test_puppet_server::puppet_server_base' --verbose
  rm -rf gce_mongodb_test_puppet_server
fi

# Now sync this git repository for the first time to the right puppet directory if needed
if ! test -d '/root/.ssh'; then
  mkdir /root/.ssh
  chmod 700 /root/.ssh
fi

if ! grep -q '^github.com' /root/.ssh/authorized_keys; then
  echo 'github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==' > /root/.ssh/known_hosts
fi

if ! test -d '/etc/puppetlabs/code/environments/production/.git'; then
  cd /etc/puppetlabs/code/environments/production
  git init
  git remote add origin git@github.com:nightw/gce-mongodb-demo.git
  git fetch origin
  git checkout -b master --track origin/master
fi

# From this point forward the puppet server + the puppet client running on the node should take care of the rest of the setting up the node
