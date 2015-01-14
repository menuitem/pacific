class {"postgresql":
		postgresqlVersion => hiera("database", "9.3.5"),
		applicationName => hiera("applicationName", "myApp")
}
#postgresql module definition
class postgresql ($postgresqlVersion, $applicationName){
	$initdCommand = $::osfamily ? {
			Debian => "update-rc.d postgresstart defaults",
			RedHat => "chkconfig --add postgresstart"
		}
	$packages = $::osfamily ? {
		Debian => ["wget","libreadline-dev","zlib1g-dev","flex","bison"],#"libpq5","libpq-dev"],
		RedHat => ["wget", "bison-devel","openssl-devel","readline-devel","zlib-devel","gcc", "gcc-c++", "automake", "autoconf",  "make"]
	}
	if $postgresqlVersion['version'] !~ /^[0-9]\.[0-9]\.[0-9]$/ {
		notice("Postgresql default version: 9.3.5")
		$postgresqlToInstall = "9.3.5"
	}else{
		$postgresqlToInstall = $postgresqlVersion['version']
	}
	if chomp($::postgresqlversion) != chomp($postgresqlToInstall) {
		$osSrcDir = "/usr/local/src"
		package { $packages:
			ensure => installed,
			before => Exec["postgresql-configure"],
		}
		exec {"wget-postgresql-source":
			command =>"wget http://ftp.postgresql.org/pub/source/v$postgresqlToInstall/postgresql-$postgresqlToInstall.tar.gz",
			path => ['/usr/bin','/bin','/sbin'],
			cwd => $osSrcDir,
			creates => "$osSrcDir/postgresql-$postgresqlToInstall.tar.gz",
			timeout => 0,
		}
		exec {"untar-postgresql-source":
			# environment => "postgresql_DIR=$osSrcDir/postgresql-$postgresqlToInstall",
			command =>"tar -xvf /usr/local/src/postgresql-$postgresqlToInstall.tar.gz",
			path    => ['/bin'],
			cwd => "$osSrcDir",
			require => Exec["wget-postgresql-source"],
			creates => "/usr/local/src/postgresql-$postgresqlToInstall",
		}
		exec {"postgresql-configure":
			command =>"$osSrcDir/postgresql-$postgresqlToInstall/configure",
			# path    => ['/bin','/usr/bin'],
			cwd => "$osSrcDir/postgresql-$postgresqlToInstall",
			require => Exec["untar-postgresql-source"],
			timeout => 0,
		}
		exec {"postgresql-make":
			command =>"make",
			path    => ['/usr/bin/:/bin'],
			cwd => "$osSrcDir/postgresql-$postgresqlToInstall",
			require => Exec["postgresql-configure"],
			timeout => 0,
			# creates => "$osSrcDir/postgresql-$postgresqlToInstall/.libs",
		}
		exec {"postgresql-make-install":
			command =>"make install",
			path    => ['/usr/bin/:/bin'],
			cwd => "$osSrcDir/postgresql-$postgresqlToInstall",
			timeout => 0,
			require => Exec["postgresql-make"],
			# creates => "$osSrcDir/postgresql-$postgresqlToInstall/.libs/libpcrecpp.so.0.0.1T",
		}
		file{"/etc/puppet/modules/stdlib/lib/facter/postgresql.rb":
		require => Exec['postgresql-make-install'],
		content => "
		require 'facter'
		postgresqlversion = nil
		if FileTest.exists?(\"/usr/local/pgsql/bin/postgres\")
			postgresqlversion = Facter::Util::Resolution.exec(\"/usr/local/pgsql/bin/postgres -V\").split(\" \")[2].scan(/[0-9]\\.[0-9]\\.[0-9]/)[0].chomp || \"undef\"
		end

		Facter.add(\"postgresqlversion\") do
		    setcode do
		        postgresqlversion
		    end
		end
		"	
		}
		#add start script for our postgres instalation
		exec { "cpStartScript":
			command => "cp /usr/local/src/postgresql-$postgresqlToInstall/contrib/start-scripts/linux /usr/bin/postgresql",
			path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
			require => Exec['postgresql-make-install'],
			creates =>"/etc/init.d/postgresql",
		}
		file { "/usr/bin/postgresql":
			ensure => file,
			mode => 755,
			require => Exec["cpStartScript"],
		}
		#we need to create password file for db root user and for our app user with 660 mode
		#we need to create directory for our database "/usr/local/pgsql/data/", with postgress ownership
		#we have to start database
		#we have to create user and database for our ap
		# add postgres user
		group { "postgres":
        	ensure => present,
        	gid => 1002,
        	require => Exec[postgresql-make-install],
		}
		user { "postgres":
		    ensure      => present, 
		    shell       => '/bin/bash',
		    home        => '/var/lib/postgresql',
		    system      => true,                      #Makes sure user has uid less than 500
		    managehome  => true,
		    comment     => "postgresql manager",
		    require => Group["postgres"],
		}
		$dbRootPaswd = "/var/lib/postgresql/.dbPass"
		$dataBaseDir = "/usr/local/pgsql/data"
		$appDbPaswd = "/var/lib/postgresql/.${applicationName}AppPass"
		$appDbUserName = $applicationName
		exec { "$dbRootPaswd":
			command => "tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1 |tr -d '\n' > $dbRootPaswd",
			path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
			user => "postgres",
			require =>User['postgres'],
			creates => "$dbRootPaswd",
		}
		file { "$dbRootPaswd":
			ensure => file,
			owner => "postgres",
			group => "postgres",
			mode => 660,
			require => Exec["$dbRootPaswd"],
		}
		exec { "$appDbPaswd":
			command => "tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1 |tr -d '\n' > $appDbPaswd",
			path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
			user => "postgres",
			creates => "$appDbPaswd",
			require => Exec["$dbRootPaswd"],
		}
		file { "$appDbPaswd":
			ensure => file,
			owner => "postgres",
			group => "postgres",
			mode => 660,
			require => Exec["$appDbPaswd"],
		}
		file { "$dataBaseDir":
			ensure => directory,
			owner => "postgres",
			group => "postgres",
			require => Exec['postgresql-make-install'],
		}
		exec { "init-database":
			command => "/usr/local/pgsql/bin/initdb -D $dataBaseDir --pwfile=$dbRootPaswd",
			user => "postgres",
			creates => "/usr/local/pgsql/data/postgresql.conf",
			require => File ["$dbRootPaswd","$dataBaseDir"],
		}
		file{"postgresstart":
			path => "/etc/init.d/postgresstart",
			content => "#!/usr/bin/env bash
# chkconfig: 2345 95 20
cd /usr/local/pgsql/data
/usr/bin/postgresql start",
			require => Exec["init-database"],
			mode => 755,
		}
		exec { "start-postgres":
			command => "/usr/local/pgsql/bin/pg_ctl -D /usr/local/pgsql/data -l serverlog start",
			# command => '/etc/init.d/postgresstart',
			path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
			cwd => "/usr/local/pgsql/data",
			user => "postgres",
			require => File["postgresstart"],
		}
		exec { "add to autostart":
			path => '/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin',
			command => $initdCommand,
			require => File["postgresstart"],
		}
		exec { "link psql":
			path => '/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin',
			command => "ln -s /usr/local/pgsql/bin/psql /usr/bin/psql",
			require => File["postgresstart"],
		}
	}
	notice("$appDbPaswd")
}
# tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1 |tr -d > /var/lib/postgresql/.BlogAppPass
# "/usr/local/pgsql/bin/pg_ctl -D /usr/local/pgsql/data -l serverlog start",