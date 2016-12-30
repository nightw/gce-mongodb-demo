#!/bin/bash

set -euf -o pipefail

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

# Setting up puppet agent config file
cat >/etc/puppetlabs/puppet/puppet.conf <<EOF
[agent]
  server = puppet-server
  noop = false
  report = true
  runinterval = 300
  splay = false
  usecacheonfailure = true
EOF

# Starting puppet agent
service puppet start

# From this point forward the puppet server + the puppet client running on the node should take care of the rest of the setting up the node
