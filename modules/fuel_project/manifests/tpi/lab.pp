# Used for deployment of TPI lab
class fuel_project::tpi::lab (
  #$btsync_secret = $fuel_project::tpi::params::btsync_secret,
  $sudo_commands = [ '/sbin/ebtables', '/sbin/iptables' ],
  $local_home_basenames = [ 'jenkins' ],
  $mtu = $fuel_project::tpi::params::mtu,
) {

  class { '::tpi::nfs_client' :
    local_home_basenames => $local_home_basenames,
  }

  class { '::fuel_project::jenkins::slave' :
    run_tests          => true,
    sudo_commands      => $sudo_commands,
    ldap               => true,
    build_fuel_plugins => true,
  }

  File<| title == 'jenkins-sudo-for-build_iso' |> {
    content => template('fuel_project/tpi/jenkins-sudo-for-build_iso'),
  }

  class { '::tpi::vmware_lab' : }
  class { '::tpi::nfsserver' : }

  # execute 'apt-get update'
  exec { 'apt-update':                    # exec resource named 'apt-update'
    command => '/usr/bin/apt-get update'  # command this resource will run
  }

  # these packages will be installed from tpi apt repo defined in hiera
  $tpi_packages = [
    'linux-image-3.13.0-100-generic',
    'linux-image-extra-3.13.0-100-generic',
    'linux-headers-3.13.0-100',
    'linux-headers-3.13.0-100-generic',
    'sudo-ldap',
    'zsh',
    'atop',
    'git-review',
    'htop',
    'mc',
    'tcpdump',
    'most',
    'nfs-kernel-server',
    'nfs-common',
    'libpam-ck-connector',
    'python-paramiko'
  ]

  ensure_packages($tpi_packages)


  # transparent hugepage defragmentation leads to slowdowns
  # in our environments (kvm+vmware workstation), disable it
  file { '/etc/init.d/disable-hugepage-defrag':
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('fuel_project/tpi/disable-hugepage-defrag.erb'),
  }

  service { 'disable-hugepage-defrag':
    ensure  => 'running',
    enable  => true,
    require => File['/etc/init.d/disable-hugepage-defrag'],
  }

  file { '/etc/sudoers.d/tpi' :
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => template('fuel_project/tpi/tpi.sudoers.d.erb'),
  }

  file { '/etc/dhcp/dhclient.conf':
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('fuel_project/tpi/dhclient.conf.erb'),
  }
  file { '/etc/modprobe.d/kvm.conf':
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('fuel_project/tpi/kvm.conf.erb'),
  }
  
  ## to avoid network problems with jumbo frames 
  #
  # This discussion: http://ubuntuforums.org/showthread.php?t=1284176 implies that when 
  # you have 'auto eth0' the mtu is set by the dhcp server and cannot be overriden in eth0.cfg. 
  # They have some suggestions there, but I simply set the mtu in /etc/rc.local
  # Edit: This bug https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1317811 
  # seems to cover this issue. To prevent the network errors, you need to also run the command:
  # sudo ethtool -K eth0 sg off
  # Or you will continue to have errors.
  exec { 'ethtool sg off':
    command => 'for link in $(ip link show | grep -v ether | grep eth | cut -d ":" -f2); do sudo ethtool -K $link sg off; done',
  }
}
