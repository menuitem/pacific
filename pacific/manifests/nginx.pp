include stdlib
#nginx module call
class {"nginx":
		webserver => hiera("webserver")
}
class installPCRE($pcreToInstall){
	# PCRE - Perl Compatible Regular Expressions
	# http://www.pcre.org/
	$cwd = "/usr/local/src"
	exec {"wget-pcre-source":
		command =>"wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-$pcreToInstall.tar.gz",
		path => ['/usr/bin', '/bin', '/sbin'],
		cwd => $cwd,
		creates => "$cwd/pcre-$pcreToInstall.tar.gz",
	}
	exec {"untar-pcre-source":
		environment => "PCRE_DIR=$cwd/pcre-$pcreToInstall",
		command =>"tar -xvf /usr/local/src/pcre-$pcreToInstall.tar.gz",
		path    => ['/bin'],
		cwd => "/usr/local/src",
		require => Exec["wget-pcre-source"],
		creates => "/usr/local/src/pcre-$pcreToInstall",
	}	
}
#nginx module definition
class nginx ($webserver){
	$initdCommand = $::osfamily ? {
		Debian => "update-rc.d nginxstart defaults",
		RedHat => "chkconfig --add nginxstart"
	}
	$pcreToInstall="8.36"
	class {"installPCRE": pcreToInstall=>"8.36"}
	# require installPCRE
	$packages = $::osfamily ? {
		Debian => ["wget","build-essential","libcurl4-openssl-dev", "ruby-dev", "libssl-dev", "zlib1g-dev"],
		RedHat => ["wget","ruby-devel", "openssl-devel", "libcurl-devel", "zlib-devel"]
	}
	if $webserver['version'] !~ /^[0-9]\.[0-9]\.[0-9]$/ {
		notice("Wrong nginx version: ${webserver['version']}")
		$nginxToInstall = "1.7.2"
	}else{
		$nginxToInstall = $webserver['version']
	}
	if chomp($::nginxversion) != chomp($nginxToInstall) {
		package { $packages:
			ensure => installed,
			before => Exec['configure-nginx']
		}
		# install passenger gem
		exec {'gemPassenger':
			command => 'gem install passenger --no-rdoc --no-ri',
			path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
			unless => "gem list passenger |grep passenger",
		}
		exec {"wget-nginx-source":
			command =>"wget http://nginx.org/download/nginx-$nginxToInstall.tar.gz",
			path => ['/usr/bin', '/bin', '/sbin'],
			cwd => "/usr/local/src",
			creates => "/usr/local/src/nginx-$nginxToInstall.tar.gz",
		}
		exec {"untar-nginx-source":
			command =>"tar -xvf /usr/local/src/nginx-$nginxToInstall.tar.gz",
			path    => ['/usr/bin','/bin','/sbin'],
			cwd => "/usr/local/src",
			require => Exec["wget-nginx-source"],
			creates => "/usr/local/src/nginx-$nginxToInstall",
		}
		exec {"configure-nginx":
			command =>"/usr/local/src/nginx-$nginxToInstall/configure \
				--prefix=/usr/local/nginx                   \
				--sbin-path=/usr/sbin/nginx           \
				--conf-path=/usr/local/nginx/nginx.conf     \
				--pid-path=/var/run/nginx.pid         \
				--lock-path=/var/run/nginx.lock       \
				--error-log-path=/var/log/nginx/error.log \
				--http-log-path=/var/log/nginx/access.log \
				--with-http_gzip_static_module        \
				--with-http_stub_status_module        \
				--with-http_ssl_module                \
				--with-pcre=/usr/local/src/pcre-$pcreToInstall \
				--with-file-aio                       \
				--with-http_realip_module             \
				--without-http_scgi_module            \
				--without-http_uwsgi_module           \
				--without-http_fastcgi_module \
				--add-module=${::passengerroot}/ext/nginx",
			path => ["/usr/local/src/nginx-$nginxToInstall:/usr/local/bin:/bin:/usr/bin:/sbin"],
			cwd => "/usr/local/src/nginx-$nginxToInstall",
			require => Exec["untar-nginx-source","gemPassenger"],
			timeout => 0,
		}
		exec {"make":
			path => ['/usr/bin','/bin','/sbin'],
			cwd => "/usr/local/src/nginx-$nginxToInstall",
			require => Exec["configure-nginx"],
			timeout => 0,
		}
		exec {"make install":
			path => ['/usr/bin','/bin','/sbin'],
			cwd => "/usr/local/src/nginx-$nginxToInstall",
			require => Exec["make"],
			timeout => 0,
		}
		file { "/usr/local/nginx/sites-available":
			ensure => "directory",
			require => Exec["make install"],
		}
		file { "/usr/local/nginx/sites-enabled":
			ensure => "directory",
			require => Exec["make install"],
		}
		file_line { 'include enabled':
			path => "/usr/local/nginx/nginx.conf",
			line => "    gzip  on; include /usr/local/nginx/sites-enabled/*;",
			match => "gzip  on;",
			require => Exec["make install"],
		}
		file { "/usr/local/nginx/sites-enabled/passenger.conf":
		 	ensure => present,
		 	content =>"passenger_root $::passengerroot;
    passenger_ruby /usr/bin/ruby;
    passenger_max_pool_size 10;
		 	",
			require => File["/usr/local/nginx/sites-enabled"],
		}
		file { "/etc/init.d/nginxstart":
		 	ensure => present,
		 	content => "#!/usr/bin/env bash
# chkconfig: 2345 95 20
/usr/sbin/nginx
",
			mode => 755,
			require => Exec["make install"],
		}
		exec { "add to autostart":
			path => '/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin',
			command => $initdCommand,
			require => File["/etc/init.d/nginxstart", "/usr/local/nginx/sites-enabled/passenger.conf"],
		}
		exec { "start-server":
			path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
  			command => "/usr/sbin/nginx",
			unless => "/usr/bin/test -f /run/nginx.pid",
			require => Exec["add to autostart"],
		}
	}
}


# centos built by gcc 4.4.7 20120313 (Red Hat 4.4.7-3) (GCC) 
# TLS SNI support enabled
# configure arguments: --prefix=/usr/share/nginx --sbin-path=/usr/sbin/nginx --conf-path=/usr/local/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --http-client-body-temp-path=/var/lib/nginx/tmp/client_body --http-proxy-temp-path=/var/lib/nginx/tmp/proxy --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi --http-scgi-temp-path=/var/lib/nginx/tmp/scgi --pid-path=/var/run/nginx.pid --lock-path=/var/lock/subsys/nginx --user=nginx --group=nginx --with-file-aio --with-ipv6 --with-http_ssl_module --with-http_realip_module --with-http_addition_module --with-http_xslt_module --with-http_image_filter_module --with-http_geoip_module --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gzip_static_module --with-http_random_index_module --with-http_secure_link_module --with-http_degradation_module --with-http_stub_status_module --with-http_perl_module --with-mail --with-mail_ssl_module --with-debug --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector --param=ssp-buffer-size=4 -m32 -march=i686 -mtune=atom -fasynchronous-unwind-tables' --with-ld-opt=-Wl,-E
######################