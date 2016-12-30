class gce_mongodb_test_base (
  $ntp_servers = [ 'metadata.google.internal' ],
) {

  # Set up an NTP server
  class { '::ntp':
    servers => $ntp_servers,
    iburst_enable => true,
  }

}
