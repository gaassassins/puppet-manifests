# Class: jenkins::slave
#
class jenkins::slave (
  $java_package = $::jenkins::params::slave_java_package,
  $authorized_keys = $::jenkins::params::slave_authorized_keys,
  $user = $::jenkins::params::swarm_user,
  $password = $::jenkins::params::swarm_password,
) inherits ::jenkins::params {
  ensure_packages([$java_package])

  if (!defined(User[$user])) {
    user { $user :
      ensure     => 'present',
      name       =>  $user,
      password   =>  $password,
      shell      => '/bin/bash',
      home       => '/home/jenkins',
      managehome => true,
      system     => true,
      comment    => 'Jenkins',
    }
  }

  create_resources(ssh_authorized_key, $authorized_keys, {
    ensure  => 'present',
    user    => $user,
    require => [
      User[$user],
      Package[$java_package],
    ],
  })
}
