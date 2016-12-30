class gce_mongodb_test_puppet_server {

  include gce_mongodb_test_puppet_server::puppet_server_base
  include gce_mongodb_test_puppet_server::cron_repo_sync
  include gce_mongodb_test_puppet_server::mongodb_module_install

}
