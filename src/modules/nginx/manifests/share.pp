class nginx::share {
  include nginx
  include nginx::params

  $autoindex = $nginx::params::autoindex
  $server_name = $nginx::params::server_name
  $service = $nginx::params::service

  file { 'share.conf' :
    path => '/etc/nginx/sites-enabled/share.conf',
    ensure => present,
    mode => '0644',
    owner => 'root',
    group => 'root',
    content => template('nginx/share.conf.erb'),
  }

  if $external_host {
    Class['firewall_defaults::pre'] ->
    firewall { '1000 allow nginx connections' :
      dport => 80,
      action => 'accept',
    }
  }

  File['share.conf']~>
    Service[$service]
}