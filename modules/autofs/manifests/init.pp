#
# Class: autofs
#
# manages autofs (master and maps)
#
class autofs {

   include chroot::params

	package { autofs: name => "autofs", ensure => present }

	service { "autofs":
		name       => "autofs",
		ensure     => running,
		enable     => true,
		hasrestart => true,
		hasstatus  => true,
		require    => Package["autofs"],
		subscribe  => File["autofs.master"],
	}

	file { "autofs.master":
		path    => "/etc/auto.master",
		mode    => 644,
		owner   => "root",
		group   => "root",

		# allow host specific files
		content => inline_template(file("/etc/puppet/modules/autofs/templates/auto.master-$hostname.erb", "/etc/puppet/modules/autofs/templates/auto.master.erb")),

		require => Package[autofs],
		ensure  => present,
	}

	file { "autofs.red":
		path    => "/etc/auto.red",
		mode    => 644,
		owner   => "root",
		group   => "root",
		content => inline_template(file("/etc/puppet/modules/autofs/templates/auto.red-$hostname.erb", "/etc/puppet/modules/autofs/templates/auto.red.erb")),
		require => Package[autofs],
		notify  => Service[autofs],
		ensure  => present,
	}

	file { "/etc/sysconfig/autofs":
		mode    => 644,
		owner   => "root",
		group   => "root",
	   source => "puppet:///modules/autofs/autofs.verbose",	
		require => Package[autofs],
		notify  => Service[autofs],
		ensure  => present,
	}
}
