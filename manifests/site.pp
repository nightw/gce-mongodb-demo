node /^puppet-server.*/ {

  include gce_mongodb_test_base
  include gce_mongodb_test_puppet_server

}

node /^mongodb-rs-.*/ {

  include gce_mongodb_test_base
  include gce_mongodb_test_mongodb_autoscale

}
