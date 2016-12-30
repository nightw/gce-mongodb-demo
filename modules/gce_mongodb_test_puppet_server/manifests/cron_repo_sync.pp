class gce_mongodb_test_puppet_server::cron_repo_sync {

  # Adding a cron job to syncronize the puppet control repo every minute
  # Please note: this is a _really_ bad solution, in production use r10k and
  # git push hooks or an other sane solution instead of this hack, thank you
  file { '/etc/cron.d/puppet-repo-sync':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    content => "* * * * * root 'cd /etc/puppetlabs/code/environments/production && /usr/bin/git pull'\n",
  }

}
