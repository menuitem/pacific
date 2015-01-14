include stdlib
#apply module call
class {"passenger":
	rubyVersion => hiera("rubyVersion", "2.1.2"),
	# railsVersion => hiera("railsVersion"),
	# applicationName => hiera("applicationName"),
	webserver => hiera("webserver"),
}
#passenger module definition
class passenger ($rubyVersion, $webserver){
	if $rubyVersion !~ /^[0-9]\.[0-9]\.([0-9]?[0-9])([[:alnum:]]+)?/ {
		notice("Wrong ruby version: ${rubyVersion}")
		$rubyToInstall = "2.1.2"
	}else{
		$rubyToInstall = $rubyVersion
	}
	if $webserver['deploymentUser'] {
			$user = $webserver['deploymentUser']
	}else {
		$user = $webserver['sshUser']
	}
	exec { 'gem-install-passenger':
		command => "gem install passenger --no-ri --no-rdoc",
		path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
		# user => $user,
		creates => "/usr/local/bin/passenger",
	}
}