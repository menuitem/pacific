include stdlib
#rubyrvm module call
class {"rubyrbenv":
		rubyVersion => hiera("rubyVersion", "2.1.2"),
		webserver => hiera("webserver"),
		railsVersion => hiera("railsVersion")
}
#rbenv module definition
class rubyrbenv ($rubyVersion,$webserver,$railsVersion){
	$packages = $::osfamily ? {
		Debian => ["wget","curl", "git-core", "libssl-dev", "ruby-dev", "libsqlite3-dev","libreadline-dev"],
		RedHat => ["wget","curl", "git", "ruby-devel", "sqlite-devel", "openssl-devel","readline-devel"]
	}
	$deploymentUser = $webserver['deploymentUser']
	if $rubyVersion !~ /^[0-9]\.[0-9]\.([0-9]?[0-9])([[:alnum:]]+)?/ {
		notice("Wrong ruby version: ${rubyVersion}")
		$rubyToInstall = "2.1.2"
	}else{
		$rubyToInstall = $rubyVersion}
	if chomp($::rubyversion) != chomp($rubyToInstall) {	
	if $webserver['deploymentUser'] {
			$user = $webserver['deploymentUser']
	}else {
		$user = $webserver['sshUser']
	}
		package { $packages:
			ensure => installed,
			before => User["$user"],
		}
		# exec {"make-clean":
		# 	path    => "/usr/local/src/ruby-$rubyToInstall:/usr/bin:/bin:/sbin",
		# 	cwd => "/usr/local/src/ruby-$rubyToInstall",
		# 	command => "make clean",
		# 	timeout => 0,
		# 	onlyif => "test -d /usr/local/src/ruby-$rubyToInstall",
		# }

		user { "$user":
			ensure => present, 
			shell => '/bin/bash',
			managehome => true,
			groups => ["adm"], #group "www-data" doesnr exists on centos
			system => true,                      #Makes sure user has uid less than 500
			comment => "Deployment user",
			# require => Exec["make-clean"],
		}
		exec {"wget-ruby-source":
			command =>"wget http://cache.ruby-lang.org/pub/ruby/ruby-$rubyToInstall.tar.gz",
			path => ['/usr/bin','/bin','/sbin'],
			cwd => "/usr/local/src",
			creates => "/usr/local/src/ruby-$rubyToInstall.tar.gz",
			unless => "test -d /home/$user/.ruby/ruby-$rubyToInstall",
			require => User["$user"],
		}
		exec {"untar-ruby-source":
			command =>"tar -xvf /usr/local/src/ruby-$rubyToInstall.tar.gz",
			path => ['/usr/bin','/bin','/sbin'],
			cwd => "/usr/local/src",
			require => Exec["wget-ruby-source"],
			unless => "test -d /home/$user/.ruby/ruby-$rubyToInstall",
			creates => "/usr/local/src/ruby-$rubyToInstall",
		}
		exec {"configure-ruby":
			command =>"/usr/local/src/ruby-$rubyToInstall/./configure --pre=/home/$user/.ruby/ruby-$rubyToInstall \
			--disable-install-doc",
			path    => "/usr/local/src/ruby-$rubyToInstall:/usr/bin:/bin:/sbin",
			cwd => "/usr/local/src/ruby-$rubyToInstall",
			require => Exec["untar-ruby-source"],
			timeout => 0,
			unless => "test -d /home/$user/.ruby/ruby-$rubyToInstall",
		}
		exec {"make":
			path    => "/usr/local/src/ruby-$rubyToInstall:/usr/bin:/bin:/sbin",
			cwd => "/usr/local/src/ruby-$rubyToInstall",
			timeout => 0,
			require => Exec["configure-ruby"],
			unless => "test -d /home/$user/.ruby/ruby-$rubyToInstall",
		}
		exec {"make install":
			path    => "/usr/local/src/ruby-$rubyToInstall:/usr/bin:/bin:/sbin",
			cwd => "/usr/local/src/ruby-$rubyToInstall",
			timeout => 0,
			require => Exec["make"],
			unless => "test -d /home/$user/.ruby/ruby-$rubyToInstall",
		}
		#chang owner
		file { "/home/$user/.ruby":
			ensure => directory,
			recurse => true,
			owner => "$user",
			group => "$user",
			require => Exec['make install'],
		}
	}
}
# gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3
# PATH="/home/lucjan/.ruby/ruby-2.1.2/bin:$::path"