class tpi::nfsserver (
  $nfs_paths = [ '/var/nfs', '/var/nfs2', ]
) {

  $packages = [
    'nfs-kernel-server',
    'nfs-common',
  ]

   file { $nfs_paths:
     ensure => directory,
     mode   => '0755',
     owner  => 'nobody',
     group  => 'nogroup',
     recurse => true, 
   }

  file { '/etc/exports':                            
    ensure  => file,
    mode    => '0755',
    owner   => 'root',                                                      
    group   => 'root',                                                      
    require => File [ $nfs_paths ],
    content => template('tpi/exports.erb'),
  }                                                                         

  service { 'nfs-kernel-server':
    ensure    => 'running',
    enable    => true,
    require   => [ 
                   File [ $nfs_paths],
                   Package[ $packages ],
                 ]
  }

  exec { 'exportfs':
    command => 'exportfs -a',
    subscribe => Service ['nfs-kernel-server'],
  }
}
