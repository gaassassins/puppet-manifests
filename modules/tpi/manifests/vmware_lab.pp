#VMWare Workstation lab
class tpi::vmware_lab (
  $vmware_ws_installer = 'VMware-Workstation-Full-10.0.2-1744117.x86_64.bundle',
  $vmware_ws_serial = '',
  $vmware_ws_envs = [ 'vsphere',  ],
  $rsync_server = '127.0.0.1',
  $vmware_default_public_gw = '172.16.0.1',
) {

  $vmware_packages=[
    'libxtst6',
    'libxcursor1',
    'libxinerama1',
    'libxi6',
    'libpam-ck-connector',
  ]

  ensure_packages($vmware_packages)

  $vmware_home='/var/lib/vmware'
  $vmware_shared_home="${vmware_home}/Shared VMs"

  file { [ $vmware_home, $vmware_shared_home ]:
    ensure => directory,
    mode   => '0755',
    owner  => 'vmware',
    recurse => true,
  }

  rsync::get { '/etc/vmware/':
    source    => "rsync://${rsync_server}/storage/vmware-envs/config/vmware/",
    purge     => true,
    recursive => true,
    options   => '-aS',
    onlyif    => [
                  '! pgrep vmware-vmx',
                  '! test -f /var/lib/vmware_nodeploy',
                 ],
    timeout   => 0,
  }

  exec { 'flush_workstation_network':
    command => "iface=$(ip route get ${vmware_default_public_gw} | cut -d' ' -f3-3 | tr -d '\n'); [ ! -z $iface ] && ip address flush $iface || echo 'no iface with such address'",
    onlyif    => [ '! test -f /var/lib/vmware_nodeploy' ] ,
  }

  exec { 'workstation_network_restart':
    command => 'vmware-networks --stop; vmware-networks --start',
    onlyif    => [ '! test -f /var/lib/vmware_nodeploy' ] ,
  }

  file { '/etc/vmware/networking':
    ensure  => 'present',
    mode    => '0655',
    owner   => 'root',
    group   => 'root',
    content => template('tpi/workstation_networking.erb'),
    require => [
      Rsync::Get['/etc/vmware/'],
      Exec['flush_workstation_network'],
      Exec['workstation_network_restart'],
    ],
  }

  $vmware_env_sources=suffix(prefix($vmware_ws_envs,"rsync://${rsync_server}/storage/vmware-envs/"),'/')
  $rsync_source = join($vmware_env_sources, ' ')

  rsync::get { "'${vmware_shared_home}'" :
    source    => $rsync_source,
    purge     => false,
    recursive => true,
    options   => '-aS --delete',
    require   => File[$vmware_shared_home],
    onlyif    => [
                  '! pgrep vmware-vmx',
                  '! test -f /var/lib/vmware_nodeploy',
                 ],
    timeout   => 0,
  }

  validate_re(
    $vmware_ws_serial,
    '^[A-Z0-9][A-Z0-9\-]*[A-Z0-9]$',
    'VMWare Workstation serial is invalid'
  )

  exec { 'install_vmware_workstation':
    command => "echo | /storage/${vmware_ws_installer}\
    --console --required --eulas-agreed\
    --set-setting vmware-workstation serialNumber ${vmware_ws_serial}",
    creates => '/usr/bin/vmware',
    onlyif    => [ '! test -f /var/lib/vmware_nodeploy' ] ,
    require => [
      Class['::tpi::nfs_client'],
      Rsync::Get['/etc/vmware/'],
      Rsync::Get["'${vmware_shared_home}'"]
    ]
  }

  service { 'vmware':
    ensure    => 'running',
    enable    => true,
    hasstatus => false,
    pattern   => 'vmware-authdlauncher',
    require   => Exec['install_vmware_workstation'],
    subscribe => User['vmware'],
  }

  service { 'vmware-workstation-server':
    ensure    => 'running',
    enable    => true,
    hasstatus => false,
    pattern   => 'vmware-hostd',
    require   => Exec['install_vmware_workstation'],
    subscribe => User['vmware'],
  }

  service { 'vmware-USBArbitrator':
    ensure    => 'running',
    enable    => true,
    hasstatus => false,
    pattern   => 'vmware-usbarbitrator',
    require   => Exec['install_vmware_workstation'],
    subscribe => User['vmware'],
  }

  user { 'vmware' :
    ensure   => 'present',
    home     => $vmware_home,
    password => $vmware_password,
    comment  => 'VMWare Workstation user',
    name     => 'vmware',
    shell    => '/bin/false',
  }
}
