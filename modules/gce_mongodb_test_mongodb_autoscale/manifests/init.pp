class gce_mongodb_test_mongodb_autoscale {

  file { '/etc/profile.d/fix_locale_for_mongodb.sh':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    source  => 'puppet:///modules/gce_mongodb_test_mongodb_autoscale/etc/profile.d/fix_locale_for_mongodb.sh',
  }

  class { '::mongodb::globals':
    manage_package_repo => true,
    version             => '3.4.1',
    bind_ip             => '0.0.0.0',
    require             => File['/etc/profile.d/fix_locale_for_mongodb.sh'],
  }

  class { '::mongodb::client':
    require => Class['Mongodb::Globals'],
  }

  class { '::mongodb::server':
    # Please note: the next two options are a _really_ bad idea to use in
    # production MongoDB server, they are only here to make the startup of the
    # nodes faster for the purposes o f this demo. Do *NOT* use them in
    # production ever! Thank you.
    smallfiles      => true,
    noprealloc      => true,
    # Replicaset config: name
    replset         => 'rs',
    require         => Class['Mongodb::Client'],
  }

  # Clean up script for unavailable members (most likely shut down by the
  # autoscaler, so it is expected that they will not come up again)
  # Please note: this is a very ugly workaround since the replicaset member
  # removal is not implemented in the puppet-mongodb module, see:
  # https://github.com/puppetlabs/puppetlabs-mongodb/blob/master/lib/puppet/provider/mongodb_replset/mongo.rb#L177
  file { '/root/remove_old_rs_members.js':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    source  => 'puppet:///modules/gce_mongodb_test_mongodb_autoscale/root/remove_old_rs_members.js',
  }

  # Only run the replicaset initialization and management tasks on the first
  # node from the list of designated MongoDB replicaset nodes
  if $::hostname == $::mongo_rs_members_from_discovery[0] {

    # This is coming from the fact added to this Puppet module, see
    # ../lib/facter/mongo_rs_members_from_discovery.rb
    $rs_members = $::mongo_rs_members_from_discovery.map |$rs_member| { "${rs_member}:27017" }

    mongodb_replset { 'rs':
      ensure  => present,
      members => $rs_members,
      require => Class['Mongodb::Server'],
      before  => File['/root/remove_old_rs_members.js'],
    }

    file { '/etc/cron.d/remove_old_mongodb_rs_members':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      content => "* * * * * root /usr/bin/mongo --norc /root/remove_old_rs_members.js\n",
      require => File['/root/remove_old_rs_members.js'],
    }

  } else {

    # And now remove the cron job if we're not on the first node
    file { '/etc/cron.d/remove_old_mongodb_rs_members':
      ensure  => absent,
    }

  }

}
