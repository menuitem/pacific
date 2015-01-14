include stdlib
#apache module call
class {"apache":
		apacheVersion => hiera("webserver", "2.4.10")
}
#apache module definition
class apache ($apacheVersion){
	$packages = $::osfamily ? {
		Debian => ["wget","libcurl4-openssl-dev","ruby-dev","libsqlite3-dev"],
		RedHat => ["wget","ruby-devel","openssl-devel","libcurl-devel","sqlite-devel","gcc", "gcc-c++", "automake", "autoconf",  "make"]
	}
	if $apacheVersion['version'] !~ /^[0-9]\.[0-9]\.([0-9][0-9]?)$/ {
		notice("Wrong apache version: ${apacheVersion['version']}")
		$apacheToInstall = "2.4.10"
	}else{
		$apacheToInstall = $apacheVersion['version']
	}
	$initdCommand = $::osfamily ? {
		Debian => "update-rc.d apachestart defaults",
		RedHat => "chkconfig --add apachestart"
	}	
	notice("\$apacheToInstall: $apacheToInstall")
	if chomp($::apacheversion) != chomp($apacheToInstall) {	
		$aprToInstall = "1.5.1"
		$aprUtilToInstall = "1.5.4"
		$pcreToInstall = "8.36"
		#Install APR
		$osSrcDir = "/usr/local/src"
		package { $packages:
			ensure => installed,
			before => Exec['wget-apr-source']
		}
		exec {"wget-apr-source":
			command =>"wget https://archive.apache.org/dist/apr/apr-$aprToInstall.tar.gz",
			path => ['/usr/bin', '/bin', '/sbin'],
			cwd => $osSrcDir,
			creates => "$osSrcDir/apr-$aprToInstall.tar.gz",
			require => Exec["untar-httpd-source"],
		}
		exec {"untar-apr-source":
			command =>"tar -xvf /usr/local/src/apr-$aprToInstall.tar.gz",
			path => ['/usr/bin/:/bin'],
			cwd => "$osSrcDir",
			require => Exec["wget-apr-source"],
			creates => "$osSrcDir/apr-$aprToInstall",
		}
		file { "/usr/local/src/httpd-$apacheToInstall/srclib/apr":
			ensure => "directory",
			alias => "create apr",
			require => Exec["untar-apr-source","untar-httpd-source"],
		}
		exec {"cp-apr":
			command =>"cp -rf /usr/local/src/apr-$aprToInstall/* /usr/local/src/httpd-$apacheToInstall/srclib/apr",
			path => ['/usr/bin/:/bin'],
			cwd => "$osSrcDir",
			require => File["create apr"],
			# creates => "/usr/local/src/httpd-$apacheToInstall/srclib/apr",
		}	
		# APR UTIL
		exec {"wget-apr-util-source":
			command =>"wget https://archive.apache.org/dist/apr/apr-util-$aprUtilToInstall.tar.gz",
			path    => ['/usr/bin/:/bin'],
			cwd => $osSrcDir,
			creates => "$osSrcDir/apr-util-$aprUtilToInstall.tar.gz",
			require => Exec["cp-apr"],
		}
		exec {"untar-apr-util-source":
			command =>"tar -xvf /usr/local/src/apr-util-$aprUtilToInstall.tar.gz",
			path    => ['/usr/bin/:/bin'],
			cwd => "$osSrcDir",
			require => Exec["wget-apr-util-source"],
			creates => "$osSrcDir/apr-util-$aprUtilToInstall",
		}
		file { "/usr/local/src/httpd-$apacheToInstall/srclib/apr-util":
			ensure => "directory",
			alias => "create apr-util",
			require => Exec["untar-apr-util-source","untar-httpd-source"],
		}
		exec {"cp-apr-util":
			command =>"cp -rf /usr/local/src/apr-util-$aprUtilToInstall/* /usr/local/src/httpd-$apacheToInstall/srclib/apr-util/",
			path    => ['/usr/bin/:/bin'],
			cwd => "$osSrcDir",
			require => File["create apr-util"],
			# creates => "$osSrcDir/apr-util",
		}	
		# PCRE - Perl Compatible Regular Expressions 8.36
		# http://www.pcre.org/
		exec {"wget-pcre-source":
			command =>"wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-$pcreToInstall.tar.gz",
			path => ['/usr/bin', '/bin', '/sbin'],
			cwd => $osSrcDir,
			creates => "$osSrcDir/pcre-$pcreToInstall.tar.gz",
			require => Exec["cp-apr-util"],
			timeout => 0,
		}
		exec {"untar-pcre-source":
			# environment => "PCRE_DIR=$osSrcDir/pcre-$pcreToInstall",
			command =>"tar -xvf /usr/local/src/pcre-$pcreToInstall.tar.gz",
			path    => ['/bin'],
			cwd => "$osSrcDir",
			require => Exec["wget-pcre-source"],
			creates => "/usr/local/src/pcre-$pcreToInstall",
		}
		exec {"pcre-configure":
			command =>"$osSrcDir/pcre-$pcreToInstall/configure --prefix=/usr/local/lib",
			# path    => ['/bin','/usr/bin'],
			cwd => "$osSrcDir/pcre-$pcreToInstall",
			require => Exec["untar-pcre-source"],
			timeout => 0,
			# creates => "$osSrcDir/pcre-$pcreToInstall/Makefile",
		}
		exec {"pcre-make":
			command =>"make",
			path    => ['/usr/bin/:/bin'],
			cwd => "$osSrcDir/pcre-$pcreToInstall",
			require => Exec["pcre-configure"],
			timeout => 0,
			# creates => "$osSrcDir/pcre-$pcreToInstall/.libs",
		}
		exec {"pcre-make-install":
			command =>"make install",
			path    => ['/usr/bin/:/bin'],
			cwd => "$osSrcDir/pcre-$pcreToInstall",
			require => Exec["pcre-make"],
			timeout => 0,
			# creates => "$osSrcDir/pcre-$pcreToInstall/.libs/libpcrecpp.so.0.0.1T",
		}
		#Installing apache
		exec {"wget-httpd-source":
			command =>"wget https://archive.apache.org/dist/httpd/httpd-$apacheToInstall.tar.gz",
			path => ['/usr/bin','/bin','/sbin'],
			cwd => $osSrcDir,
			creates => "$osSrcDir/httpd-$apacheToInstall.tar.gz",
			timeout => 0,
			# require => Exec["pcre-make-install"],
		}
		exec {"untar-httpd-source":
			command =>"tar -xvf $osSrcDir/httpd-$apacheToInstall.tar.gz",
			path => ['/usr/bin','/bin','/sbin'],
			cwd => $osSrcDir,
			require => Exec["wget-httpd-source"],
			creates => "$osSrcDir/httpd-$apacheToInstall",
			# unless => "/usr/local/apache2/bin/httpd -v |grep $apacheToInstall",
		}
		exec {"httpd-configure":
			command =>"$osSrcDir/httpd-$apacheToInstall/./configure \
--with-pcre=/usr/local/lib \
--enable-so \
--with-included-apr \
--enable-pie \
--enable-mpms-shared=all",
			path    => ['/usr/bin/:/bin'],
			cwd => "$osSrcDir/httpd-$apacheToInstall",
			require => Exec["pcre-make-install"],
			timeout => 0,
			# creates => "$osSrcDir/httpd-$apacheToInstall/Makefile",
		}
		exec {"httpd-make":
			command =>"make",
			path => ['/usr/bin/:/bin'],
			cwd => "$osSrcDir/httpd-$apacheToInstall",
			require => Exec["httpd-configure"],
			timeout => 0,
			# creates => "$osSrcDir/httpd-$apacheToInstall/httpd",
		}
		exec {"httpd-make-install":
			command =>"make install",
			path => ['/usr/bin/:/bin'],
			cwd => "$osSrcDir/httpd-$apacheToInstall",
			require => Exec["httpd-make"],
			timeout => 0,
			# creates => "/usr/local/src/httpd-$apacheToInstall/httpd",
		}
		file{"/etc/puppet/modules/stdlib/lib/facter/apache.rb":
		require => Exec['httpd-make-install'],
		content => "
		require 'facter'
		apacheversion = nil
		if FileTest.exists?(\"/usr/local/apache2/bin/httpd\")
	    	apacheversion = apacheversion = Facter::Util::Resolution.exec(\"/usr/local/apache2/bin/httpd -v\").split(\" \")[2].scan(/[0-9]\\.[0-9]\\.[0-9]?[0-9]/)[0].chomp || \"undef\"
		end

		Facter.add(\"apacheversion\") do
		    setcode do
		        apacheversion
		    end
		end
		"	
		}	
		exec { "passenger-install-apache2-module":
			path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
			command => "passenger-install-apache2-module --apxs2-path='/usr/local/apache2/bin/apxs' -a",
			require => Exec['httpd-make-install'],
			creates => "$::passengerroot/buildout/apache2/mod_passenger.so",
			timeout => 0,
		}
		file { "/usr/local/apache2/sites-available":
			ensure => "directory",
			require => Exec["passenger-install-apache2-module"],
		}
		file { "/usr/local/apache2/sites-enabled":
			ensure => "directory",
			require => Exec["passenger-install-apache2-module"],
		}

		file_line { "httpd.conf append line":
			ensure => present,
			line => "Include /usr/local/apache2/sites-enabled/*.conf",
			path => "/usr/local/apache2/conf/httpd.conf",
			require => File["/usr/local/apache2/sites-enabled"],
		}
		file { "/usr/local/apache2/sites-enabled/passenger.conf":
		 	ensure => present,
		 	content =>"LoadModule passenger_module $::passengerroot/buildout/apache2/mod_passenger.so
 PassengerRoot $::passengerroot
 PassengerMaxPoolSize 10
 PassengerDefaultRuby /usr/bin/ruby
 PassengerLogLevel 3",
		require => File_line["httpd.conf append line"],
		}
		file { "/etc/init.d/apachestart":
		 	ensure => present,
			mode => 755,
			require => File["/usr/local/apache2/sites-enabled/passenger.conf"],
		}
		file_line { "/etc/init.d/apachestart":
		 	ensure => present,
			path => "/etc/init.d/apachestart",
			line => "#!/usr/bin/env bash",
			require => File["/etc/init.d/apachestart"],
		}
		file_line { "chkconfig":
		 	ensure => present,
			path => "/etc/init.d/apachestart",
			line => "# chkconfig: 2345 95 20",
			require => File_line["/etc/init.d/apachestart"],
		}
		exec { "add to autostart":
			path => '/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin',
			command => $initdCommand,
			require => File_line["chkconfig"],
		}
		exec { "start-server":
			path => "/usr/local/bin:$path",
  			command => "/usr/local/apache2/bin/httpd -k start 2> /dev/null",
			require => Exec["add to autostart"],
		}
	}
}