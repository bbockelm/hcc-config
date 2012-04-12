
class yum::repo::osg {

	# OSG gpg key
	# version = 824b8603
	# release = 4e726d80

	file { "RPM-GPG-KEY-OSG":
		path => '/etc/pki/rpm-gpg/RPM-GPG-KEY-OSG',
		source => "puppet:///modules/yum/rpm-gpg/RPM-GPG-KEY-OSG",
		ensure => present,
		owner => 'root', group => 'root', mode => '0644',
	}

	yum::managed_yumrepo {

		'osg':
			descr => "OSG Software for Enterprise Linux $lsbmajdistrelease - \$basearch",
#			mirrorlist => "http://repo.grid.iu.edu/mirror/3.0/el$lsbmajdistrelease/osg-release/\$basearch",
			baseurl => "http://t2.unl.edu/osg/3.0/el$lsbmajdistrelease/osg-release/\$basearch",
			enabled => 1,
		 	gpgcheck => 1,
			gpgkey => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-OSG',
			failovermethod => 'priority',
			priority => 98,
			require => File['RPM-GPG-KEY-OSG'] ;

      'osg-testing':
         descr => "OSG Software for Enterprise Linux $lsbmajdistrelease - Testing - \$basearch",
 #        mirrorlist => "http://repo.grid.iu.edu/mirror/3.0/el$lsbmajdistrelease/osg-testing/\$basearch",
			baseurl => "http://t2.unl.edu/osg/3.0/el$lsbmajdistrelease/osg-testing/\$basearch",
         enabled => 0,
         gpgcheck => 1,
         gpgkey => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-OSG',
         failovermethod => 'priority',
         priority => 98,
         require => File['RPM-GPG-KEY-OSG'] ;

      'osg-development':
         descr => "OSG Software for Enterprise Linux $lsbmajdistrelease - Development - \$basearch",
  #       mirrorlist => "http://repo.grid.iu.edu/mirror/3.0/el$lsbmajdistrelease/osg-development/\$basearch",
			baseurl => "http://t2.unl.edu/osg/3.0/el$lsbmajdistrelease/osg-development/\$basearch",
         enabled => 0,
         gpgcheck => 1,
         gpgkey => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-OSG',
         failovermethod => 'priority',
         priority => 98,
         require => File['RPM-GPG-KEY-OSG'] ;

      'osg-contrib':
         descr => "OSG Software for Enterprise Linux $lsbmajdistrelease - Contrib - \$basearch",
  #       mirrorlist => "http://repo.grid.iu.edu/mirror/3.0/el$lsbmajdistrelease/osg-contrib/\$basearch",
			baseurl => "http://t2.unl.edu/osg/3.0/el$lsbmajdistrelease/osg-contrib/\$basearch",
         enabled => 1,
         gpgcheck => 1,
         gpgkey => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-OSG',
         failovermethod => 'priority',
         priority => 98,
         require => File['RPM-GPG-KEY-OSG'] ;

		'osg-source':
			descr => "OSG Software for Enterprise Linux $lsbmajdistrelease - \$basearch - Source",
	#		baseurl => "http://repo.grid.iu.edu/3.0/el$lsbmajdistrelease/osg-release/source/SRPMS",
			baseurl => "http://t2.unl.edu/osg/3.0/el$lsbmajdistrelease/osg-release/source/SRPMS",
			enabled => 0,
	 		gpgcheck => 1,
			gpgkey => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-OSG',
			failovermethod => 'priority',
			priority => 98,
			require => File['RPM-GPG-KEY-OSG'] ;

		'osg-debug':
			descr => "OSG Software for Enterprise Linux $lsbmajdistrelease - \$basearch - Debug",
	#		baseurl => "http://repo.grid.iu.edu/3.0/el$lsbmajdistrelease/osg-release/\$basearch/debug",
			baseurl => "http://t2.unl.edu/osg/3.0/el$lsbmajdistrelease/osg-release/\$basearch/debug",
			enabled => 0,
	 		gpgcheck => 1,
			gpgkey => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-OSG',
			failovermethod => 'priority',
			priority => 98,
			require => File['RPM-GPG-KEY-OSG'] ;

	}	# end yum::managed_yumrepo

}
