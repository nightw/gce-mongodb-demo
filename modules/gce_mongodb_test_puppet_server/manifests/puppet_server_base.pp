class gce_mongodb_test_puppet_server::puppet_server_base {

  # And initialize a Puppet server via the theforman/puppet module
  class { '::puppet':
    server                     => true,
    server_foreman             => false,
    server_reports             => 'store',
    server_external_nodes      => '',
    server_environments        => [],
    server_common_modules_path => [],
    server_jvm_min_heap_size   => '800M',
    server_jvm_max_heap_size   => '1200M',
  }

}
