class gce_mongodb_test_mongodb_autoscale {

  file { '/etc/profile.d/fix_locale_for_mongodb.sh':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    source  => 'puppet:///modules/gce_mongodb_test_mongodb_autoscale/etc/profile.d/fix_locale_for_mongodb.sh',
  }

  # Please note: the below way is *VERY* unsecure this way, it is only valid
  # for the  current demo's purposes, you should _never_ put SSH keys
  # in plain text to a public repository!
  file { '/root/.ssh':
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
  }

  file { '/root/.ssh/authorized_keys':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    source  => 'puppet:///modules/gce_mongodb_test_mongodb_autoscale/root/.ssh/authorized_keys',
    require => File['/root/.ssh'],
  }

  file { '/root/.ssh/id_rsa':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    source  => 'puppet:///modules/gce_mongodb_test_mongodb_autoscale/root/.ssh/id_rsa',
    require => File['/root/.ssh'],
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
    # nodes faster for the purposes of this demo. Do *NOT* use them in
    # production ever! Thank you.
    smallfiles      => true,
    noprealloc      => true,
    # Replicaset config: name
    replset         => 'rs',
    require         => Class['Mongodb::Client'],
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
    }

  }

}
