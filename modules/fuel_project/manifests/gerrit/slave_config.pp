# Class fuel_project::gerrit::slave_config
#
class fuel_project::gerrit::slave_config (
  $authorized_keys = {}
) {

  if (!defined(User['gerrit-replicator'])) {
    user { 'gerrit-replicator':
      ensure     => 'present',
      name       => 'gerrit-replicator',
      shell      => '/bin/bash',
      home       => '/var/lib/gerrit-replicator',
      managehome => true,
      comment    => 'Gerrit Replicator User',
      system     => true,
    }
  }

  file { '/var/lib/gerrit-replicator/.ssh/' :
    ensure  => 'directory',
    owner   => 'gerrit-replicator',
    group   => 'gerrit-replicator',
    mode    => '0700',
    require => User['gerrit-replicator'],
  }

  file { '/var/lib/gerrit/review_site/git/' :
    ensure  => 'directory',
    owner   => 'gerrit-replicator',
    group   => 'gerrit-replicator',
    require => User['gerrit-replicator'],
  }

  create_resources(ssh_authorized_key, $authorized_keys, {
    ensure  => 'present',
    user    => 'gerrit-replicator',
    require => [
      User['gerrit-replicator'],
      File['/var/lib/gerrit-replicator/.ssh/'],
    ],
  })
}
