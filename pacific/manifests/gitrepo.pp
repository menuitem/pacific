# include stdlib
#initGitRepo module call
class {"initGitRepo":
		applicationName => hiera("applicationName"),
		webserver => hiera("webserver"),
}
#initGitRepo module definition
class initGitRepo ($webserver, $applicationName){
	$sshUser = $webserver['sshUser']
	if $webserver['deploymentUser'] {
			$user = $webserver['deploymentUser']
	}else {
		$user = $sshUser
	}
	if $webserver['appDirectory'] {
			$appDirectory = $webserver['appDirectory']
	}else {
		$appDirectory = "/var/www"
	}
	$packages = $::osfamily ? {
		Debian => ["git-core"],
		RedHat => ["git"]
	}
	package { $packages:
		ensure => installed,
		before => File ["$appDirectory/$applicationName"],
	}
	user { "$user":
		ensure => present, 
		shell => '/bin/bash',
		managehome => true,
		groups => ["adm"], #group "www-data" doesnr exists on centos
		system => true,                      #Makes sure user has uid less than 500
		comment => "Deployment user",
		require => Package["$packages"],
	}
	if $webserver['deploymentUser'] or !$webserver['identityFile']{
		file { "/home/$user/.ssh":
			ensure => "directory",
		    owner  => "$user",
	    	group  => "$user",
			recurse => true,
			mode => 700,
			require => User["$user"],
			before => File ["$appDirectory/$applicationName"],
		}
		exec { "authorized_keys":
			path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
			command => "cat /tmp/$user.pub >> /home/$user/.ssh/authorized_keys",
		    user  => "$user",
		    unless => "grep `cat /tmp/$user.pub` /home/$user/.ssh/authorized_keys",
			require => File["/home/$user/.ssh"],
		}
	}
	file { "$appDirectory":
		ensure => "directory",
		before => File ["$appDirectory/$applicationName"],
	}
	file { "$appDirectory/$applicationName":
		ensure => "directory",
	    owner  => "$user",
    	group  => "$user",
		recurse => true,
		require => User["$user"],
	}
	exec { "git-init":
		command => "git init --bare ${applicationName}.git",
		path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
		user => $user,
		cwd => "$appDirectory/$applicationName",
		require => File["$appDirectory/$applicationName"],
		creates => "$appDirectory/$applicationName/${applicationName}.git",
	}
	exec { "git-clone-init":
		# command => "git clone $appDirectory/${applicationName}/${applicationName}.git $appDirectory/${applicationName}/${applicationName}",
		command => "git clone ${applicationName}.git",
		path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
		user => $user,
		cwd => "$appDirectory/$applicationName",
		require => Exec["git-init"],
		creates => "$appDirectory/$applicationName/${applicationName}",
	}
}