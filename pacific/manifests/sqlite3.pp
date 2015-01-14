class {"sqlite3":
		database => hiera("database", "9.3.5"),
		applicationName => hiera("applicationName", "myApp"),
		webserver => hiera("webserver", "myApp"),
}
#sqlite3 module definition
class sqlite3 ($database, $applicationName, $webserver){
	# I could check if gem 'sqlite3' is added to Gemfile, only if the Gemfile is there already
	$packages = $::osfamily ? {
		Debian => ["libsqlite3-dev", "sqlite3"],
		RedHat => ["sqlite-devel"]
	}
	package { $packages:
		ensure => installed,
	}
}