class zabbix::params {
  $checks = [
    'hardware.conf',
    'software.conf',
  ]

  $agent_config = '/etc/zabbix/zabbix_agentd.conf'

  $agent_packages = ['zabbix-agent']

  $agent_service = 'zabbix-agent'

  $server_config = '/etc/zabbix/zabbix_server.conf'

  $server_packages = [
    'puppet-module-puppetlabs-mysql',
    'zabbix-frontend-php',
    'zabbix-server-mysql',
  ]

  $server_service = 'zabbix-server'

  $zabbix_nets = [
    '172.18.0.0/16',
    '91.218.144.129/32',
  ]

  # MySQL options
  $innodb_buffer_pool_size = floor($::memorysize_mb/2*1024*1024)
  $innodb_file_per_table = 1
  $max_connections = 1024
}
