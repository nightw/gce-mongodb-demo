#!/bin/bash

set -euf -o pipefail

cd /tmp

# Installing release package if needed
if ! dpkg --get-selections | grep -q 'puppetlabs-release-pc1.*install'; then
  wget https://apt.puppetlabs.com/puppetlabs-release-pc1-xenial.deb
  dpkg -i puppetlabs-release-pc1-xenial.deb
  rm puppetlabs-release-pc1-xenial.deb
fi

# Installing puppet agent if needed
if ! dpkg --get-selections | grep -q 'puppet-agent.*install'; then
  apt-get update
  apt-get install -y puppet-agent
fi

# Now install puppet modules if needed
if ! test -d '/etc/puppetlabs/code/environments/production/modules/ntp'; then
  puppet module install puppetlabs-ntp --version 6.0.0
fi
if ! test -d '/etc/puppetlabs/code/environments/production/modules/puppet'; then
  puppet module install theforeman-puppet --version 7.0.0
fi

# Now get the puppet server code from this project publicly via HTTPS from GitHub and run it if needed
if ! dpkg --get-selections | grep -q 'puppetserver.*install'; then
  wget https://raw.githubusercontent.com/nightw/gce-mongodb-demo/master/puppet_server_bootstrap.pp
  /opt/puppetlabs/bin/puppet apply --verbose puppet_server_bootstrap.pp
  rm puppet_server_bootstrap.pp
fi
