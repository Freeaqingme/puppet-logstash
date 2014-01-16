# Class: logstash::install
#
# This class installs logstash
#
# == Variables
#
# Refer to logstash class for the variables defined here.
#
# == Usage
#
# This class is not intended to be used directly.
# It's automatically included by logstash
#
class logstash::install inherits logstash {

  case $logstash::install {

    if $::logstash::bool_manage_repo {
      case $::operatingsystem {
        /^(Debian|Ubuntu|Mint)$/: {
          if $::logstash::bool_firewall {
             # The before=> entry is not too relevant given that you need 
             # Service['iptables'] probably
            firewall { 'logstash-apt':
              destination    => 'packages.elasticsearch.org',
              destination_v6 => 'packages.elasticsearch.org',
              protocol       => 'tcp',
              port           => 80,
              direction      => 'output',
              before         => Apt::Repository['logstash']
            }
          }

          $tpl ='<%=@scope.lookupvar("::logstash::version").to_s.match(/\d+.\d+/)[0] %>'
          $minor_version = inline_template($tpl)
          apt::repository { 'logstash':
            url        => "http://packages.elasticsearch.org/logstash/${minor_version}/debian",
            distro     => 'stable',
            repository => 'main',
            key_url    => 'http://packages.elasticsearch.org/GPG-KEY-elasticsearch',
            key        => 'D88E42B4',
            before     => Package['logstash'],
          }

        }
        default: {
          fail('Using $manage_repo is currently only supported under Debian*')
        }
      }
    }

    package: {
      package { 'logstash':
        ensure => $logstash::manage_package,
        name   => $logstash::package,
      }
    }

    source: {

      $created_file = url_parse($logstash::real_install_source,'filename')

      if $logstash::bool_create_user == true {
        require logstash::user
        
      }
      include logstash::skel

      puppi::netinstall { 'netinstall_logstash':
        url                 => $logstash::real_install_source,
        destination_dir     => $logstash::logstash_dir,
        extract_command     => 'cp ',
        preextract_command  => $logstash::install_precommand,
        extracted_dir       => $created_file,
        owner               => $logstash::process_user,
        group               => $logstash::process_user,
        before              => File ['logstash_link'],
      }

      file { 'logstash_link':
        ensure  => "${logstash::logstash_dir}/${created_file}" ,
        path    => "${logstash::logstash_dir}/logstash.jar" ,
        require => Puppi::Netinstall ['netinstall_logstash'],
      }

    }

    puppi: {

      if $logstash::bool_create_user == true {
        require logstash::user
      }
      include logstash::skel

      puppi::project::war { 'logstash':
        source                   => $logstash::real_install_source,
        deploy_root              => $logstash::logstash_dir,
        predeploy_customcommand  => $logstash::install_precommand,
        postdeploy_customcommand => $logstash::install_postcommand,
        report_email             => 'root',
        user                     => 'root',
        auto_deploy              => true,
        check_deploy             => false,
        run_checks               => false,
        enable                   => true,
        before                   => File ['logstash_link'],
      }

      file { 'logstash_link':
        ensure  => "${logstash::logstash_dir}/${created_file}" ,
        path    => "${logstash::logstash_dir}/logstash.jar" ,
        require => Puppi::Project::War ['logstash'],
      }

    }

    default: { }

  }

}
