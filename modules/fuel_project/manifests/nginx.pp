# Class: fuel_project::nginx
#
# This class deploys Nginx.
#
class fuel_project::nginx {
  include ::nginx

  Class['::nginx::config'] -> Nginx::Resource::Vhost <| |>

  ::nginx::resource::vhost { 'stub_status' :
    ensure              => 'present',
    listen_ip           => '127.0.0.1',
    listen_port         => 61929,
    location_custom_cfg => {
      stub_status => true,
    },
  }

  if ( ! $::puppet_apply ) {
    ::nginx::resource::vhost { 'logshare' :
      ensure                 => 'present',
      listen_port            => 4637,
      gzip_types             => 'application/octet-stream',
      ssl_port               => 4637,
      ssl                    => true,
      ssl_cert               => "/var/lib/puppet/ssl/certs/${::fqdn}.pem",
      ssl_key                => "/var/lib/puppet/ssl/private_keys/${::fqdn}.pem",
      ssl_client_certificate => '/var/lib/puppet/ssl/certs/ca.pem',
      ssl_crl                => '/var/lib/puppet/ssl/crl.pem',
      ssl_verify_client      => 'on',
      www_root               => '/var/log',
    }
  }

  ensure_packages('error-pages')

  zabbix::item { 'nginx' :
    content => 'puppet:///modules/fuel_project/zabbix/nginx_items.conf',
  }

  # FIXME: Nginx manifest installs own incorrect file fastcgi_params containing
  # SCRIPT_FILENAME, which can't be overriden and in some cases is unusable
  file{ "${::nginx::config::conf_dir}/fastcgi_params": mode => '0644' }
}
