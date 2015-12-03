# lpreports::webapp
#
class lpreports::webapp (
  $nginx_server_name        = $::fqdn,
  $nginx_access_log         = '/var/log/nginx/access.log',
  $nginx_error_log          = '/var/log/nginx/error.log',
  $nginx_log_format         = undef,
  $ssl_certificate          = '/etc/ssl/certs/lpreports.crt',
  $ssl_certificate_contents = undef,
  $ssl_key                  = '/etc/ssl/private/lpreports.key',
  $ssl_key_contents         = undef,
) {
  package { 'python-lp-reports' :
    ensure => 'present',
  }

  user { 'lpreports' :
    ensure     => 'present',
    shell      => '/bin/false',
    home       => '/var/lib/lpreports',
    managehome => true,
    system     => true
  }

  file { $ssl_certificate :
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0400',
    content => $ssl_certificate_contents,
  }

  file { $ssl_key :
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0400',
    content => $ssl_key_contents,
  }

  file { '/etc/lpreports/review.json' :
    ensure  => 'present',
    owner   => 'lpreports',
    group   => 'lpreports',
    mode    => '0400',
    content => template('lpreports/review.json.erb'),
  }

  uwsgi::application { 'lpreports' :
    plugins   => 'python',
    module    => 'lpreports:wsgi',
    callable  => 'app',
    master    => true,
    processes => $::processorcount,
    socket    => '127.0.0.1:6776',
    vacuum    => true,
    uid       => 'lpreports',
    gid       => 'lpreports',
    require   => [
      User['lpreports'],
      Package['python-lp-reports'],
    ],
  }

  ::nginx::resource::vhost { 'lpreports-http' :
    ensure              => 'present',
    server_name         => [$nginx_server_name],
    listen_port         => 80,
    www_root            => '/var/www',
    access_log          => $nginx_access_log,
    error_log           => $nginx_error_log,
    format_log          => $nginx_log_format,
    location_cfg_append => {
      return => "301 https://${nginx_server_name}\$request_uri",
    },
  }

  ::nginx::resource::vhost { 'lpreports' :
    ensure              => 'present',
    listen_port         => 443,
    ssl_port            => 443,
    server_name         => [$nginx_server_name],
    ssl                 => true,
    ssl_cert            => $ssl_certificate,
    ssl_key             => $ssl_key,
    ssl_cache           => 'shared:SSL:10m',
    ssl_session_timeout => '10m',
    ssl_stapling        => true,
    ssl_stapling_verify => true,
    access_log          => $nginx_access_log,
    error_log           => $nginx_error_log,
    format_log          => $nginx_log_format,
    proxy               => $nginx_proxy_pass,
    proxy_set_header    => [
      'X-Forwarded-For $remote_addr',
      'Host $host',
    ],
    require             => [
      File[$ssl_certificate],
      File[$ssl_key],
      Package['python-lp-reports'],
    ],
  }
}