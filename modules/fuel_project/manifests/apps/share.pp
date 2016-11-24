#
# Define: fuel_project::apps::share
#
# Generic definition to create web shares
#
# Parameters:
#   [*service_fqdn*] - String, FQDN for the service, will be used as nginx's
#     server_name
#   [*path*] - String, local directory path to serve
#   [*autoindex*] - Boolean, Enables or disables nginx's autoindex operation
#   [*directory_mode*] - String, local directory path to serve mode
#   [*htpasswd*] - String, Enables or disables Basic auth nginx's feature.
#     If not empty should contain htpasswd file content
#   [*http_ro*] - Boolean, Enables or disables nginx configuration
#   [*incoming_mode*] - String, mode which files uploaded by rsync have
#   [*nginx_access_log*] - String, nginx access log path
#   [*nginx_error_log*] - String, nginx error log path
#   [*nginx_log_format*] - String, nginx log format name
#   [*outgoing_mode*] - String, mode which files downloaded by rsync have
#   [*rsync_ro*] - Boolean, Enables or disables rsync read-only module
#   [*rsync_rw*] - Boolean, Enables or disables rsync writable module
#   [*ssh_authorized_keys*] - Hash, Hash of keys(to pass to create_resources()
#     function)
#   [*sync_hosts_allow*] - Array, list of hosts to allow rsync connections from
#     if $rsync_rw is enabled
#   [*username*] - String, System user name to use as share owner
#
define fuel_project::apps::share (
  $service_fqdn,
  $path,
  $autoindex           = false,
  $directory_mode      = '0755',
  $htpasswd            = '',
  $http_ro             = true,
  $incoming_mode       = '0755',
  $nginx_access_log    = '/var/log/nginx/access.log',
  $nginx_error_log     = '/var/log/nginx/error.log',
  $nginx_log_format    = 'proxy',
  $outgoing_mode       = '0644',
  $rsync_ro            = false,
  $rsync_rw            = false,
  $ssh_authorized_keys = {},
  $sync_hosts_allow    = [],
  $username            = $title,
) {
  include ::rssh

  # only create dedicated share user if it does not exists yet
  if ! defined(User[$username]) {
    user { $username :
      ensure     => 'present',
      home       => $path,
      managehome => true,
      shell      => '/usr/bin/rssh',
      system     => true,
    }
  }

  file { $path :
    ensure  => 'directory',
    owner   => $username,
    group   => $username,
    mode    => $directory_mode,
    require => User[$username],
  }

  create_resources('ssh_authorized_key', $ssh_authorized_keys, {
    ensure  => 'present',
    user    => $username,
    require => User[$username]
  })

  if($http_ro) {
    include ::fuel_project::nginx

    if($htpasswd) {
      $vhost_cfg_append = {
        auth_basic           => '"Restricted access!"',
        auth_basic_user_file => "/etc/nginx/${title}.htpasswd",
      }
    } else {
      $vhost_cfg_append = {}
    }
    $vhost_cfg_append['disable_symlinks'] = 'if_not_owner'

    if($autoindex) {
      $vhost_cfg_append['autoindex'] = 'on'
    } else {
      $vhost_cfg_append['autoindex'] = 'off'
    }

    ::nginx::resource::vhost { $title :
      ensure              => 'present',
      listen_port         => 80,
      ipv6_enable         => true,
      ipv6_listen_port    => 80,
      ipv6_listen_options => '',
      access_log          => $nginx_access_log,
      error_log           => $nginx_error_log,
      format_log          => $nginx_log_format,
      www_root            => $path,
      server_name         => $service_fqdn,
      vhost_cfg_append    => $vhost_cfg_append,
      require             => File[$path]
    }
  }

  if($rsync_ro) {
    include ::rsync::server

    ::rsync::server::module { $title :
      comment         => $title,
      uid             => 'nobody',
      gid             => 'nogroup',
      list            => 'yes',
      lock_file       => "/var/run/rsync-${title}.lock",
      max_connections => 100,
      path            => $path,
      read_only       => 'yes',
      write_only      => 'no',
      require         => File[$path],
    }
  }

  if($rsync_rw) {
    include ::rsync::server

    ::rsync::server::module{ "${title}-sync" :
      comment         => $rsync_rw_share_comment,
      uid             => $username,
      gid             => $username,
      hosts_allow     => $sync_hosts_allow,
      hosts_deny      => ['*'],
      incoming_chmod  => $incoming_mode,
      outgoing_chmod  => $outgoing_mode,
      list            => 'yes',
      lock_file       => "/var/run/rsync-${title}-sync.lock",
      max_connections => 100,
      path            => $path,
      read_only       => 'no',
      write_only      => 'no',
      require         => [
          File[$path],
          User[$username],
        ],
    }
  }

  if($htpasswd) {
    file { "/etc/nginx/${title}.htpasswd" :
      ensure  => 'present',
      owner   => 'root',
      group   => 'www-data',
      mode    => '0440',
      content => $htpasswd,
    }
  }
}
