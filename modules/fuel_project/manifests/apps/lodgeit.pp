# Class: fuel_project::apps::lodgeit
#
class fuel_project::apps::lodgeit (
  $ssl_certificate_contents,
  $ssl_key_contents,
  $ssl_certificate_file       = '/etc/ssl/certs/paste.crt',
  $ssl_key_file               = '/etc/ssl/private/paste.key',
  $service_fqdn               = [$::fqdn],
  $nginx_access_log           = '/var/log/nginx/access.log',
  $nginx_error_log            = '/var/log/nginx/error.log',
  $nginx_log_format           = 'proxy',
  $paste_header_contents      = '<h1>Lodge It</h1>',
) {
  if (! defined(Class['::nginx'])) {
    class { '::fuel_project::nginx' :}
  }
  class { '::lodgeit::web' :}

  file { $ssl_certificate_file :
    ensure  => 'present',
    mode    => '0700',
    owner   => 'root',
    group   => 'root',
    content => $ssl_certificate_contents,
  }

  file { $ssl_key_file :
    ensure  => 'present',
    mode    => '0700',
    owner   => 'root',
    group   => 'root',
    content => $ssl_key_contents,
  }

  file { '/usr/share/lodgeit/lodgeit/views/header.html' :
    ensure  => 'present',
    content => $paste_header_contents,
    require => Class['::lodgeit::web'],
  }

  ::nginx::resource::vhost { 'paste' :
    ensure              => 'present',
    server_name         => $service_fqdn,
    listen_port         => 80,
    www_root            => '/var/www',
    access_log          => $nginx_access_log,
    error_log           => $nginx_error_log,
    format_log          => $nginx_log_format,
    location_cfg_append => {
      return => "301 https://${service_fqdn}\$request_uri",
    },
  }

  ::nginx::resource::vhost { 'paste-ssl' :
    ensure              => 'present',
    listen_port         => 443,
    ssl_port            => 443,
    server_name         => $service_fqdn,
    ssl                 => true,
    ssl_cert            => $ssl_certificate_file,
    ssl_key             => $ssl_key_file,
    ssl_cache           => 'shared:SSL:10m',
    ssl_session_timeout => '10m',
    ssl_stapling        => true,
    ssl_stapling_verify => true,
    access_log          => $nginx_access_log,
    error_log           => $nginx_error_log,
    format_log          => $nginx_log_format,
    proxy               => 'http://127.0.0.1:5000',
    proxy_redirect      => 'off',
    proxy_read_timeout  => 120,
    proxy_set_header    => [
      'X-Forwarded-For $remote_addr',
      'Host $host',
    ],
    require             => [
      File[$ssl_certificate_file],
      File[$ssl_key_file],
    ],
  }

  ::nginx::resource::location { 'paste-ssl-static' :
    ensure   => 'present',
    vhost    => 'paste-ssl',
    ssl      => true,
    ssl_only => true,
    location => '/static/',
    www_root => '/usr/share/lodgeit/lodgeit',
  }
}
