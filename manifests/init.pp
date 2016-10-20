class hosts::setup {
    host {
        'localhost':
            ip => '127.0.0.1',
            host_aliases => [
                'local.rraise.co'
            ];
    }
}

class rraise::apache_httpd_setup() inherits rraise::params {
    class { 'apache_httpd':
        ssl       => true,
        modules   => [ 'mime', 'setenvif', 'alias', 'proxy', 'cgi', 'rewrite', 'dir', 'deflate', 'expires' ],
        keepalive => 'On',
        user      => "${web_owner}",
        group     => "${web_group}",
        listen    => [ '80', '443' ],
        namevirtualhost => [ '*:80', '*:443' ],
    }
}

class php_ini::setup {
    php::ini { '/etc/php.ini':
        display_errors => 'On',
        memory_limit   => '1256M',
        date_timezone  => 'UTC',
        upload_max_filesize => '6M'
    }
    php::ini { '/etc/httpd/conf/php.ini':
        mail_add_x_header => 'Off',
        date_timezone  => 'UTC',
        memory_limit   => '1256M',
    # For the parent directory
        require           => Package['httpd'],
    }
}

class rraise::apache_vhost_config() inherits rraise::params {

    file { "/etc/sysconfig/iptables":
        ensure => present,
        owner => "root",
        group => "root",
        mode => 0700,
        source => "puppet:///modules/rraise/iptables",
        notify  => Service["iptables"]
    }


    file { "/etc/pki/tls/certs/get-local-rraise-co.crt":
        ensure => present,
        owner => "root",
        group => "root",
        mode => 0700,
        source => "puppet:///modules/rraise/get-local-rraise-co.crt",
    }

    service {
        iptables:
            enable    => true,    # default on
            ensure    => running, # start it up if it's stopped
            hasstatus => true,    # since there's no daemon
            require => File['/etc/sysconfig/iptables']
    }

    apache_httpd::file { 'rraise-vhost.conf':
        content => template('rraise/rraise.vhost.erb')
        #source => 'puppet:///modules/rraise/rraise.vhost',
    }

}

class php::xdebug-config {
    file { '/etc/php.d/xdebug.ini':
        ensure => present,
        source => "puppet:///modules/rraise/xdebug.ini",
        notify => Service['httpd'],
        require => Class['php::mod_php5'],
        owner => "root",
        group => "root"
    }

    file { '/etc/php-zts.d/xdebug.ini':
        ensure => present,
        source => "puppet:///modules/rraise/xdebug-zts.ini",
        notify => Service['httpd'],
        require => Class['php::mod_php5'],
        owner => "root",
        group => "root"
    }
}

class sudoers {
    class { 'sudo': }

    sudo::conf { 'vagrant':
        content  => "vagrant        ALL=(ALL)       NOPASSWD: ALL\nDefaults:vagrant !requiretty\n",
    }

    sudo::conf { 'veewee':
        content  => "veewee        ALL=(ALL)       NOPASSWD: ALL\n",
    }

    sudo::conf { 'admin':
        content  => "%admin ALL=NOPASSWD: ALL\n",
    }

    group { 'admin':
        ensure => present
    }

    user { 'vagrant':
        groups     => [ 'admin' ],
        require    => Group['admin']
    }

    user { 'nathan':
        groups     => [ 'admin' ],
        require    => Group['admin']
    }
}

class rraise::compass {

    if ! defined(Package['ruby-devel']) {
        package { 'ruby-devel':
            ensure => installed,
        }
    }

    if ! defined(Package['rubygems']) {
        package { ["rubygems"]:
            ensure => 'installed',
            require => [
                Package['ruby-devel'],
            ]
        }
    }

    if ! defined(Package['sass']) {
        package { ['sass']:
            ensure => 'installed',
            provider => 'gem',
            require => Package['rubygems']
        }
    }

    if ! defined(Package['compass']) {
        package { ['compass']:
            ensure => 'installed',
            provider => 'gem',
            require => Package['rubygems']
        }
    }
}

class rraise::get_nodejs() {

    if ! defined(Package['nodejs']) {
        class { 'nodejs':
            manage_repo => true,
        }
    }

}

class rraise::get_less_css() {

    package { 'less':
        ensure   => '1.7.4',
        provider => 'npm',
    }
}

class rraise::get_mcrypt() {

    package { ["libmcrypt"]:
        ensure => 'installed',
        require => [
            Yumrepo['epel'],
        ],
    }

    package { ["libmcrypt-devel"]:
        ensure => 'installed',
        require => [
            Package['libmcrypt'],
        ],
    }

    package { ["mcrypt"]:
        ensure => 'installed',
        require => [
            Package['libmcrypt-devel'],
        ],
    }
}

class rraise::get_ntp() {

    package { ["ntp"]:
        ensure => 'installed',
        require => [
            Yumrepo['epel'],
        ]
    }

    service { 'ntpd':
        enable    => true,
        require => Package['ntp']
    }
}


class rraise::get_r10k() {
    if ! defined(Package['r10k']) {
        package { ['r10k']:
            ensure   => 'installed',
            provider => 'gem',
            require  => Package['rubygems']
        }
    }
}


class rraise() inherits rraise::params {

    Exec { path => [ "/usr/local/sbin", "/usr/local/bin" , "/sbin", "/bin", "/usr/sbin", "/usr/bin", "/usr/sbin", "/sbin", "/opt/apache-ant/bin", "/root/bin" ] }

    class { 'mysql':
        db_username => $db_username,
        db_password => $db_password,
        require => [
            Yumrepo['mysql-community'],
        ]
    }

    class { 'bash':
        home => $home,
        owner => $owner,
        thegroup => $thegroup,
        env_descriptor => $env_descriptor
    }

    include git, hosts::setup, php_ini::setup, sudoers, stdlib


    class { 'rraise::get_mcrypt': }

    class { 'php::mod_php5':
        require => [
            Yumrepo['remi-php56'],
            Class['rraise::get_mcrypt']
        ]
    }

    class { 'php::cli':
        require => [
            Class['php::mod_php5']
        ]
    }

    class { 'php::xdebug-config':
        require => [
            Class['php::mod_php5']
        ]
    }

    class { 'selinux':
      mode => 'permissive'
    }

    php::module { [ 'mcrypt', 'xml', 'pdo', 'mysqlnd', 'mbstring', 'pecl-xdebug', 'gd', 'intl', 'bcmath' ]:
        require => [
            Class['php::mod_php5'],
        ],
        notify => Service['httpd']
    }
    php::module::ini { 'xmlreader': pkgname => 'xml' }

    class { 'apache_vhost_config': }

    class { 'rraise::compass': }

    class { 'rraise::get_nodejs': }
  
    class { 'rraise::get_less_css':
        require => Class['rraise::get_nodejs']
    }
  
    class { 'rraise::apache_httpd_setup': }

    class { 'rraise::get_r10k': }

    class { 'rraise::get_ntp': }

}
