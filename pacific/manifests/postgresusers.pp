#postgresqluser module call
class {"postgresqluser":
		applicationName => hiera("applicationName")
}
#postgresqluser module definition
class postgresqluser ($applicationName){	
	if $applicationName{
		$appDownName = downcase($applicationName)
		$appDbPaswd = "/var/lib/postgresql/.${applicationName}AppPass"
		$commandToRun= "create user $appDownName password '`cat $appDbPaswd`'"
		exec { "$appDbPaswd":
			command => "tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1 |tr -d '\n' > $appDbPaswd",
			path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
			user => "postgres",
			creates => "$appDbPaswd",
		}
		file { "$appDbPaswd":
			ensure => file,
			owner => "postgres",
			group => "postgres",
			mode => 660,
			require => Exec["$appDbPaswd"],
		}
		# Before we have to create user and application database in postgresql
		exec { "create-$appDownName":
			command => "echo \"$commandToRun\" | /usr/local/pgsql/bin/psql",
			path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
			user => "postgres",
			unless => "/usr/local/pgsql/bin/psql -lqt | cut -d\"|\" -f 2 | grep -w $appDownName",
			# before => Exec["git-pull"],
			cwd => "/usr/local/pgsql/data",
			require => File["$appDbPaswd"],
		}
		exec { "create-$appDownName-database":
			command => "/usr/local/pgsql/bin/psql -c \"create database $appDownName owner $appDownName\"",
			user => "postgres",
			cwd => "/usr/local/pgsql/data",
			unless => "/usr/local/pgsql/bin/psql -lqt | cut -d\"|\" -f 1 | grep -w $appDownName",
			require => Exec["create-$appDownName"], 
		}
	}else{
		notice("Please specify application name for which to create database")
	}
}
# tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1 |tr -d > /var/lib/postgresql/.BlogAppPass