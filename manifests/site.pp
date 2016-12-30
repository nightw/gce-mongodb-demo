node /^puppet-server.*/ {

  include gce_mongodb_test_base
  include gce_mongodb_test_puppet_server

}
