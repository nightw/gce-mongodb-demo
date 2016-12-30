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
