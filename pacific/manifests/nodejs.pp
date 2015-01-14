class {"nodejs":
	nodejsVersion => hiera("nodejsVersion", "v0.10.32")
}
class nodejs ($nodejsVersion){
	# $::nodejsversion is defined as facter variable which gets value from operating system
	# $nodejsVersion is class variable that falls back to "v0.10.32" because of its call
	if $nodejsVersion !~ /^v[0-9]\.[0-9][0-9]\.[0-9][0-9]$/ {
		notice("Wrong node.js version: ${nodejsVersion}")
	# $nodever = $::nodejsversion
		#cant do line belowe because Puppet can't override parameters to classes which you could do prior version 2.6, see issue http://projects.puppetlabs.com/issues/5517
		#$nodejsVersion = "v0.10.32"
		#thats why I have to work around with "else". If node version in our "data yaml file" has wrong format then v0.10.32 will be installed.
		$nodeToInstall = "v0.10.32"
	}else{
		$nodeToInstall = $nodejsVersion
	}
	if chomp($::nodejsversion) != chomp($nodeToInstall) {
		# class {"py278":}
		$packages = $::osfamily ? {
			Debian => ["wget","build-essential", "openssl", "libssl-dev"], #"pkg-config"]#,"git-core" ]
			RedHat => ["wget","ruby-devel","gcc", "gcc-c++", "automake", "autoconf",  "make"] 
		}
		package { $packages:
			ensure => installed,
			# prvider => aptitude,
		}
		exec {"wget-node-source":
			command =>"wget http://nodejs.org/dist/$nodeToInstall/node-$nodeToInstall.tar.gz",
			path => ['/usr/bin/:/bin'],
			cwd => "/usr/local/src/",
			creates => "/usr/local/src/node-$nodeToInstall.tar.gz",
			require => Package[$packages],
			timeout => 0,
		}
		exec {"untar-node-source":
			command =>"tar -xvf /usr/local/src/node-$nodeToInstall.tar.gz",
			path => ['/usr/bin/:/bin'],
			cwd => "/usr/local/src/",
			require => Exec["wget-node-source"],
			creates => "/usr/local/src/node-$nodeToInstall",
		}
		# file_line {"addpython27toconfigure":
		# 	path  => "/usr/local/src/node-$nodeToInstall/configure",
		# 	line  => versioncmp($py278::python2version, "2.6.0") ? {
		# 		1 => '#!/usr/bin/env python2.7',
		# 		0 => '#!/usr/bin/env python2.7',
		# 		/-1/ => '#!/usr/bin/env python',
		# 	},
		# 	match => '#!/usr/bin/env python',
		# 	require => Exec["untar-node-source"],
		# }
		exec {"configure-node":
			command =>"/usr/local/src/node-$nodeToInstall/./configure",
			path => ['/usr/bin/:/bin'],
			cwd => "/usr/local/src/node-$nodeToInstall",
			require => Exec["untar-node-source"],
			timeout => 0,
			# require => File_line["untar-node-source"],
		}
		exec {"make install":
			path => ['/usr/bin/:/bin'],
			cwd => "/usr/local/src/node-$nodeToInstall",
			require => Exec["configure-node"],
			timeout => 0,
		}
	}else{
		notice("Node version: $nodejsversion")
	}
}