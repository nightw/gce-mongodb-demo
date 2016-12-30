class gce_mongodb_test_puppet_server::mongodb_module_install {

  module { 'puppetlabs/mongodb':
    ensure => '0.16.0',
  }

}
