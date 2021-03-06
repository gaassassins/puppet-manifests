# Class: fuel_proect::roles::docs
#
# This class deploys docs role.
#
# Parameters:
#   [*community_hostname*] - community service hostname
#   [*community_ssl_cert_content*] - community SSL certificate contents
#   [*community_ssl_cert_filename*] - community SSL certificate path
#   [*community_ssl_key_content*] - community SSL key contents
#   [*community_ssl_key_filename*] - community SSL key path
#   [*docs_user*] - user to install docs
#   [*fuel_version*] - fuel version
#   [*hostname*] - service hostname
#   [*nginx_access_log*] - access log
#   [*nginx_error_log*] - error log
#   [*nginx_log_format*] - log format
#   [*redirect_root_to*] - redirect root to
#   [*specs_hostname*] - specs service hostname
#   [*ssh_auth_key*] - SSH authorized key
#   [*ssl_cert_content*] - SSL certificate contents
#   [*ssl_cert_filename*] - SSL certificate file path
#   [*ssl_key_content*] - SSL key contents
#   [*ssl_key_filename*] - SSL key file path
#   [*www_root*] - www root path
#
class fuel_project::roles::docs (
  $community_hostname          = 'docs.fuel-infra.org',
  $community_ssl_cert_content  = '',
  $community_ssl_cert_filename = '/etc/ssl/community-docs.crt',
  $community_ssl_key_content   = '',
  $community_ssl_key_filename  = '/etc/ssl/community-docs.key',
  $docs_user                   = 'docs',
  $fuel_version                = '6.0',
  $hostname                    = 'docs.mirantis.com',
  $nginx_access_log            = '/var/log/nginx/access.log',
  $nginx_error_log             = '/var/log/nginx/error.log',
  $nginx_log_format            = undef,
  $redirect_root_to            = 'http://www.mirantis.com/openstack-documentation/',
  $specs_hostname              = 'specs.fuel-infra.org',
  $ssh_auth_key                = undef,
  $ssl_cert_content            = '',
  $ssl_cert_filename           = '/etc/ssl/docs.crt',
  $ssl_key_content             = '',
  $ssl_key_filename            = '/etc/ssl/docs.key',
  $www_root                    = '/var/www',
) {
  if ( ! defined(Class['::fuel_project::nginx']) ) {
    class { '::fuel_project::nginx' : }
  }

  user { $docs_user :
    ensure     => 'present',
    shell      => '/bin/bash',
    managehome => true,
  }

  ensure_packages('error-pages')

  if ($ssl_cert_content and $ssl_key_content) {
    file { $ssl_cert_filename :
      ensure  => 'present',
      mode    => '0600',
      group   => 'root',
      owner   => 'root',
      content => $ssl_cert_content,
    }
    file { $ssl_key_filename :
      ensure  => 'present',
      mode    => '0600',
      group   => 'root',
      owner   => 'root',
      content => $ssl_key_content,
    }
    Nginx::Resource::Vhost <| title == $hostname |> {
      ssl         => true,
      ssl_cert    => $ssl_cert_filename,
      ssl_key     => $ssl_key_filename,
      listen_port => 443,
      ssl_port    => 443,
    }
    ::nginx::resource::vhost { "${hostname}-redirect" :
      ensure              => 'present',
      server_name         => [$hostname],
      listen_port         => 80,
      www_root            => $www_root,
      access_log          => $nginx_access_log,
      error_log           => $nginx_error_log,
      format_log          => $nginx_log_format,
      location_cfg_append => {
        return => "301 https://${hostname}\$request_uri",
      },
    }
    $ssl = true
  } else {
    $ssl = false
  }

  if ($community_ssl_cert_content and $community_ssl_key_content) {
    file { $community_ssl_cert_filename :
      ensure  => 'present',
      mode    => '0600',
      group   => 'root',
      owner   => 'root',
      content => $community_ssl_cert_content,
    }
    file { $community_ssl_key_filename :
      ensure  => 'present',
      mode    => '0600',
      group   => 'root',
      owner   => 'root',
      content => $community_ssl_key_content,
    }
    Nginx::Resource::Vhost <| title == $community_hostname |> {
      ssl         => true,
      ssl_cert    => $community_ssl_cert_filename,
      ssl_key     => $community_ssl_key_filename,
      listen_port => 443,
      ssl_port    => 443,
    }
    ::nginx::resource::vhost { "${community_hostname}-redirect" :
      ensure              => 'present',
      server_name         => [$community_hostname],
      listen_port         => 80,
      www_root            => $www_root,
      access_log          => $nginx_access_log,
      error_log           => $nginx_error_log,
      format_log          => $nginx_log_format,
      location_cfg_append => {
        return => "301 https://${community_hostname}\$request_uri",
      },
    }
    $community_ssl = true
  } else {
    $community_ssl = false
  }

  if ($ssh_auth_key) {
    ssh_authorized_key { 'fuel_docs@jenkins' :
      user    => $docs_user,
      type    => 'ssh-rsa',
      key     => $ssh_auth_key,
      require => User[$docs_user],
    }
  }

  ::nginx::resource::vhost { $community_hostname :
    ensure              => 'present',
    server_name         => [$community_hostname],
    listen_port         => 80,
    www_root            => $www_root,
    access_log          => $nginx_access_log,
    error_log           => $nginx_error_log,
    format_log          => $nginx_log_format,
    location_cfg_append => {
      'rewrite' => {
        '^/$'                => '/fuel-dev',
        '^/express/?$'       => '/openstack/express/latest',
        '^/(express/.+)'     => '/openstack/$1',
        '^/fuel/?$'          => "/openstack/fuel/fuel-${fuel_version}",
        '^/(fuel/.+)'        => '/openstack/$1',
        '^/openstack/fuel/$' => "/openstack/fuel/fuel-${fuel_version}",
      },
    },
    vhost_cfg_append    => {
      'error_page 403'         => '/fuel-infra/403.html',
      'error_page 404'         => '/fuel-infra/404.html',
      'error_page 500 502 504' => '/fuel-infra/5xx.html',
    }
  }

  # error pages for community
  ::nginx::resource::location { "${community_hostname}-error-pages" :
    ensure   => 'present',
    vhost    => $community_hostname,
    location => '~ ^\/fuel-infra\/(403|404|5xx)\.html$',
    ssl      => true,
    ssl_only => true,
    www_root => '/usr/share/error_pages',
    require  => Package['error-pages'],
  }

  # Disable fuel-master docs on community site
  ::nginx::resource::location { "${community_hostname}/openstack/fuel/fuel-master" :
    vhost               => $community_hostname,
    location            => '~ \/openstack\/fuel\/fuel-master\/.*',
    www_root            => $www_root,
    ssl                 => $community_ssl,
    ssl_only            => $community_ssl,
    location_cfg_append => {
      return => 404,
    },
  }

  # Disable mirantis fuel docs on community site
  ::nginx::resource::location { "${community_hostname}/openstack/" :
    vhost               => $community_hostname,
    location            => '~ \/openstack\/.*',
    www_root            => $www_root,
    ssl                 => $community_ssl,
    ssl_only            => $community_ssl,
    location_cfg_append => {
      return => 404,
    },
  }

  ::nginx::resource::location { "${community_hostname}/fuel-dev" :
    vhost               => $community_hostname,
    location            => '/fuel-dev',
    location_alias      => "${www_root}/fuel-dev-docs/fuel-dev-master",
    ssl                 => $community_ssl,
    ssl_only            => $community_ssl,
    location_cfg_append => {
      'rewrite' => {
        '^/fuel-dev/(.*)$' => 'http://docs.openstack.org/developer/fuel-docs',
      }
    },
  }

  # Bug: https://bugs.launchpad.net/fuel/+bug/1473440
  ::nginx::resource::location { "${community_hostname}/fuel-qa" :
    vhost          => $community_hostname,
    location       => '/fuel-qa',
    location_alias => "${www_root}/fuel-qa/fuel-master",
    ssl            => $community_ssl,
    ssl_only       => $community_ssl,
  }

  ::nginx::resource::vhost { $hostname :
    ensure              => 'present',
    server_name         => [$hostname],
    listen_port         => 80,
    www_root            => $www_root,
    access_log          => $nginx_access_log,
    error_log           => $nginx_error_log,
    format_log          => $nginx_log_format,
    location_cfg_append => {
      'rewrite' => {
        '^/$'                                           => $redirect_root_to,
        '^/fuel-dev/?(.*)$'                             => "http://${community_hostname}/fuel-dev/\$1",
        '^/express/?$'                                  => '/openstack/express/latest',
        '^/(express/.+)'                                => '/openstack/$1',
        '^/fuel/?$'                                     => "/openstack/fuel/fuel-${fuel_version}",
        '^/(fuel/.+)'                                   => '/openstack/$1',
        '^/openstack/fuel/$'                            => "/openstack/fuel/fuel-${fuel_version}",
        '^/openstack/fuel/fuel-9.0/operations.html$'    => '/openstack/fuel/fuel-8.0/operations.html permanent',
        '^/openstack/fuel/fuel-master/operations?(.*)$' => '/openstack/fuel/fuel-master/index.html permanent',
        '^/mcp/$'                                       => '/mcp/0.5/index.html permanent',
      },
    },
    vhost_cfg_append    => {
      'error_page 403'         => '/mirantis/403.html',
      'error_page 404'         => '/mirantis/404.html',
      'error_page 500 502 504' => '/mirantis/5xx.html',
    }
  }

  # error pages for primary docs
  ::nginx::resource::location { "${hostname}-error-pages" :
    ensure   => 'present',
    vhost    => $hostname,
    location => '~ ^\/mirantis\/(403|404|5xx)\.html$',
    ssl      => true,
    ssl_only => true,
    www_root => '/usr/share/error_pages',
    require  => Package['error-pages'],
  }

  if (! defined(File[$www_root])) {
    file { $www_root :
      ensure  => 'directory',
      mode    => '0755',
      owner   => $docs_user,
      group   => $docs_user,
      require => User[$docs_user],
    }
  } else {
    File <| title == $www_root |> {
      owner   => $docs_user,
      group   => $docs_user,
      require => User[$docs_user],
    }
  }

  ::nginx::resource::vhost { $specs_hostname :
    server_name         => [$specs_hostname],
    access_log          => $nginx_access_log,
    error_log           => $nginx_error_log,
    www_root            => $www_root,
    location_cfg_append => {
      'rewrite' => {
        '^/(.*)$' => 'https://specs.openstack.org/openstack/fuel-specs/$1',
      },
    },
  }

  #method to restrict access to specified location
  $restrict_location=hiera_hash('fuel_project::roles::docs::restrict_location')

  create_resources(::nginx::resource::location, $restrict_location, {
    ssl            => true,
    ssl_only       => true,
    www_root       => $www_root,
  })
}
