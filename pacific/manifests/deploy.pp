include stdlib
#apply module call
class {"deploy":
	rubyVersion => hiera("rubyVersion", "2.1.2"),
	railsVersion => hiera("railsVersion"),
	applicationName => hiera("applicationName"),
	webserver => hiera("webserver"),
	database => hiera("database"),
	subURI => hiera("subURI"),
	branch => hiera("branch", false),
	currentCommit => hiera("currentCommit", false),
}
#deploy module definition
class deploy ($rubyVersion,$railsVersion,$webserver,$database,$applicationName,$subURI,$branch,$currentCommit){
	$webserverName = $webserver['name']
	$appName = upcase($applicationName)
	$appDownName = downcase($applicationName)
	$appDbPaswd = "/var/lib/postgresql/.${applicationName}AppPass"
	if $webserver['port'] {
			$port = $webserver['port']
	}else {
		$port = "80"
	}
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
	if $webserver['appDirectory'] {
			$appDirectory = $webserver['appDirectory']
	}else {
		$appDirectory = "/var/www"
	}
	if $subURI =~ /^\/[[:alnum:]]+/ {
		$subURIvalidated = $subURI
	}else{
		$subURIvalidated = "/$subURI"
	}
	if $database['IP'] {
		$databaseServer = $database['IP']
	}else{
		$databaseServer = $webserver['IP']
	}
	if $webserver['name'] =~ /webrick/ {
		$serverNameStart = "${webserverName}${applicationName}start"
	}else{
		$serverNameStart = "${webserverName}start"
	}

	#set database, set other database params before deploying 
	if $database['name'] =~ /postgres/ {
		if $database['port']{
			$dbPort = $database['port']
		}else{
			$dbPort = "5432"
		}
		exec { "apply postgresusers":
			path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
			command => "puppet apply /usr/local/pacific/manifests/postgresusers.pp",
			before => Exec["git-reset", "git-checkout"]
		}
		file_line{"pg gemfile":
			path => "/var/www/$applicationName/$applicationName/Gemfile",
			line => "gem 'pg'",
			before => Exec["bundle"],
			require => Exec["git-checkout"],
		}
		file_line{"del password":
			path => "/var/www/$applicationName/$applicationName/config/database.yml",
			line => "password",
			ensure => absent,
			require => Exec["git-checkout"],
		}
		file_line{"add password $webserverName":
			path => "/var/www/$applicationName/$applicationName/config/database.yml",
			line => "  password: <%= ENV[\"PG_$appName\"] %>",
			require => File_line["del password"],
		}
		file_line{"add database":
			path => "/var/www/$applicationName/$applicationName/config/database.yml",
			line => "  database: $appDownName",
			require => File_line["add password $webserverName"],
		}
		file_line{"add username":
			path => "/var/www/$applicationName/$applicationName/config/database.yml",
			line => "  username: $appDownName",
			require => File_line["add database"],
		}
		if $webserver['IP'] == $databaseServer {
			file_line{"add host":
				path => "/var/www/$applicationName/$applicationName/config/database.yml",
				line => "  host: 127.0.0.1",
				require => File_line["add username"],
			}
		}else{
			file_line{"add host":
				path => "/var/www/$applicationName/$applicationName/config/database.yml",
				line => "  host: 127.0.0.1",
				require => File_line["add username"],
			}
		}
		file_line{"add dbPort":
			path => "/var/www/$applicationName/$applicationName/config/database.yml",
			line => "  port: $dbPort",
			require => File_line["add host"],
		}
		if $webserver['IP'] == $databaseServer {
			file_line { "add pass to serverstart":
				path => "/etc/init.d/$serverNameStart",
				match =>"PG_$appName=", 
				line =>"PG_$appName=`cat $appDbPaswd`",			
				require => File_line["add password $webserverName"],
			}
		}else{
			file_line { "add pass to serverstart":
				path => "/etc/init.d/$serverNameStart",
				match =>"PG_$appName=", 
				line =>"PG_$appName=`cat /var/www/$applicationName/$applicationName/config/.${applicationName}AppPass`",			
				require => File_line["add password $webserverName"],
			}
		}
		file_line { "export PG_$appName":
			path => "/etc/init.d/$serverNameStart",
			line =>"export PG_$appName",
			require => File_line ["$serverNameStart export"],
			# before => Exec["start-server"],
			before => File_line["add pass to serverstart"],
		}
		exec { "rake db":
			command => "rake db:migrate RAILS_ENV=production",
			path => "/home/$user/.ruby/ruby-$rubyToInstall:/home/$user/.ruby/ruby-$rubyToInstall/bin:/usr/local/bin:$path",
			user => $user,
			cwd => "$appDirectory/$applicationName/$applicationName",
			before => Exec["rake assets"],
			require => [Exec["bundle"],File_line["add pass to serverstart"]],
		}
	}else{
		exec { "rake db":
		command => "rake db:migrate RAILS_ENV=production",
		path => "/home/$user/.ruby/ruby-$rubyToInstall:/home/$user/.ruby/ruby-$rubyToInstall/bin:/usr/local/bin:$path",
		user => $user,
		cwd => "$appDirectory/$applicationName/$applicationName",
		before => Exec["rake assets"],
		require => Exec["bundle"],
		}
	}

	exec { "git-reset":
		command => "git reset --hard",
		path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
		user => $user,
		cwd => "$appDirectory/$applicationName/$applicationName",
		onlyif => "/usr/bin/test -f $appDirectory/$applicationName/$applicationName/.git/index",
	}
	if $branch {
		exec { "git-pull-$branch":
			command => "git pull origin $branch",
			path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
			user => $user,
			cwd => "$appDirectory/$applicationName/$applicationName",
			require => Exec["git-reset"],
		}
		exec { "git-checkout":
			command => "git checkout $currentCommit",
			path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
			user => $user,
			cwd => "$appDirectory/$applicationName/$applicationName",
			require => Exec["git-pull-$branch"],
		}	
	}else{
		exec { "git-checkout":
			command => "git checkout $currentCommit",
			path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
			user => $user,
			cwd => "$appDirectory/$applicationName/$applicationName",
			require => Exec["git-reset"],
		}
	} 
	exec { "install-bundler":
		path => ["/home/$user/.ruby/ruby-$rubyToInstall:/home/$user/.ruby/ruby-$rubyToInstall/bin:$path"],
		command => "gem install bundler --no-rdoc --no-ri",
		user => $user,
		creates => "/home/$user/.ruby/ruby-$rubyToInstall:/home/$user/.ruby/ruby-$rubyToInstall/bin/bundler",
		require => Exec["git-checkout"],
	}
	exec { "bundle":
		command => "bundle",
		path => "/home/$user/.ruby/ruby-$rubyToInstall:/home/$user/.ruby/ruby-$rubyToInstall/bin:/usr/local/bin:/usr/local/pgsql/bin:$path",
		user => $user,
		cwd => "$appDirectory/$applicationName/$applicationName",
		require => Exec["install-bundler","git-checkout"],
	}
	exec { "rake assets":
		command => "rake assets:precompile",
		path => "/home/$user/.ruby/ruby-$rubyToInstall:/home/$user/.ruby/ruby-$rubyToInstall/bin:/usr/local/bin:$path",
		user => $user,
		cwd => "$appDirectory/$applicationName/$applicationName",
		onlyif => "/bin/grep \"config.assets.compile = true\" $appDirectory/$applicationName/$applicationName/config/environments/production.rb",
		require => Exec["bundle"],
	}
	
	if versioncmp($railsVersion, '4.0.0') > 0 {
		#we need to generate secret token
		file_line { 'change_secret':
			path => "$appDirectory/$applicationName/$applicationName/config/secrets.yml",
			line => "  secret_key_base: <%= ENV[\"SECRET_KEY_BASE_$appName\"] %>",
			match => 'SECRET_KEY_BASE',
			require => Exec["git-checkout"],
		}
		exec { "generate-secret":
			path => "/home/$user/.ruby/ruby-$rubyToInstall:/home/$user/.ruby/ruby-$rubyToInstall/bin:/usr/local/bin:$path",
			# path => "/usr/local/bin:$path",
			user => $user,
			cwd => "$appDirectory/$applicationName/$applicationName/config",
			command => "rake secret > .sec.key",
			require => File_line["change_secret"],
			creates => "$appDirectory/$applicationName/$applicationName/config/.sec.key",
		}
	}else{
		#rails 3
		$escapeStr = '::Application.config.secret_token'
		file_line { 'change_secret':
			path => "$appDirectory/$applicationName/$applicationName/config/initializers/secret_token.rb",
			line => "${applicationName}${escapeStr} = ENV[\"SECRET_KEY_BASE_$appName\"].to_s",
			match => "$applicationName::Application.config.secret_token",
			require => Exec["git-checkout"],
		}
		exec { "generate-secret":
			path => "/home/$user/.ruby/ruby-$rubyToInstall:/home/$user/.ruby/ruby-$rubyToInstall/bin:/usr/local/bin:$path",
			user => $user,
			cwd => "$appDirectory/$applicationName/$applicationName/config",
			command => "rake secret > .sec.key",
			creates => "$appDirectory/$applicationName/$applicationName/config/.sec.key",
			require => File_line["change_secret"],
		}
	}

##apache
	if downcase($webserver['name']) =~ /apache/{
		
		if $subURI == "/" {
			file { "/usr/local/apache2/sites-available/$applicationName.conf":
			 	ensure => present,
			 	content =>"<VirtualHost *:$port>
    ServerName localhost
    DocumentRoot $appDirectory/$applicationName/$applicationName/public
    <Directory $appDirectory/$applicationName/$applicationName/public>
    	PassengerRuby /home/$user/.ruby/ruby-$rubyToInstall/bin/ruby
        Allow from all
        Options -MultiViews
        # Uncomment this if you're on Apache >= 2.4:
        Require all granted
    </Directory>
     # ErrorLog $appDirectory/$applicationName/$applicationName/log/error.log
</VirtualHost>",
				require => Exec["rake db"],
			}
		}else{
			file { "/usr/local/apache2/sites-available/$applicationName.conf":
			 	ensure => present,
			 	content =>"<VirtualHost *:$port>
    Alias $subURIvalidated $appDirectory/$applicationName/$applicationName/public
    ServerName $::hostname
    <Location $subURIvalidated>
        PassengerBaseURI $subURIvalidated
        PassengerAppRoot $appDirectory/$applicationName/$applicationName
    	PassengerRuby /home/$user/.ruby/ruby-$rubyToInstall/bin/ruby
    </Location>
    <Directory $appDirectory/$applicationName/$applicationName/public>
        Allow from all
        Options -MultiViews
        # Uncomment this if you're on Apache >= 2.4:
        Require all granted
    </Directory>
     # ErrorLog $appDirectory/$applicationName/$applicationName/log/error.log
</VirtualHost>",
				require => Exec["rake db"],
			}
		}
		exec { "link site":
			path => "/usr/local/bin:$path",
  			command => "sudo ln -fs /usr/local/apache2/sites-available/$applicationName.conf /usr/local/apache2/sites-enabled/$applicationName.conf",
			before => Exec["start-server"], 
			require => File["/usr/local/apache2/sites-available/$applicationName.conf"],
		}
		file_line { "add port $port":
			path => "/usr/local/apache2/conf/httpd.conf",
			line =>"Listen $port",
			before => Exec["start-server"],
		}
		exec { "stop-server":
	  		command => "/usr/local/apache2/bin/httpd -k graceful-stop",
			before => Exec["start-server"],
			require => Exec["bundle"],
		}
		# secret keys
		file_line { 'apachestart':
			path => "/etc/init.d/apachestart",
			line =>"SECRET_KEY_BASE_$appName=`cat $appDirectory/$applicationName/$applicationName/config/.sec.key`",			
			require => Exec ["generate-secret"],
		}
		file_line { 'apachestart export':
			path => "/etc/init.d/apachestart",
			line =>"export SECRET_KEY_BASE_$appName",
			require => File_line ['apachestart'],
		}
		file_line{"remove httpd":
			path => "/etc/init.d/apachestart",
			line => "/usr/local/apache2/bin/httpd -k graceful",
			ensure => absent,
			require => File_line["apachestart export"],
		}
		file_line{"add httpd":
			path => "/etc/init.d/apachestart",
			line => "/usr/local/apache2/bin/httpd -k graceful",
			require => File_line["remove httpd"],
		}
		exec { "start-server":
			path => "/usr/local/bin:$path",
  			command => "/etc/init.d/apachestart",
			require => [File_line["add httpd"],File["/usr/local/apache2/sites-available/$applicationName.conf"]],
		}
	}
##end apache

##nginx
if downcase($webserver['name']) =~ /nginx/{
	if $subURI == "/" {
		file { "/usr/local/nginx/sites-available/$applicationName.conf":
		 	ensure => present,
		 	content =>"server {
    listen $port;
    passenger_ruby /home/$user/.ruby/ruby-$rubyToInstall/bin/ruby;
    server_name localhost $hostname;
    root $appDirectory/$applicationName/$applicationName/public;
    passenger_enabled on;
}",
			require => Exec["rake db"],
		}
	}else{
		file { "/usr/local/nginx/sites-available/$applicationName.conf":
		 	ensure => present,
		 	content =>"server {
    listen $port;
    server_name localhost $hostname;
    #root $appDirectory/$applicationName/$applicationName;
    location ~ ^$subURI(/.*|\$) {
    	passenger_ruby /home/$user/.ruby/ruby-$rubyToInstall/bin/ruby;
        alias $appDirectory/$applicationName/$applicationName/public\$1;  # <-- be sure to point to 'public'!
        passenger_base_uri $subURI;
        passenger_app_root $appDirectory/$applicationName/$applicationName;
        passenger_document_root $appDirectory/$applicationName/$applicationName/public;
        passenger_enabled on;
    }
}",
			require => Exec["rake db"],
		}
	}
		exec { "link site":
			path => "/usr/local/bin:$path",
  			command => "sudo ln -fs /usr/local/nginx/sites-available/$applicationName.conf /usr/local/nginx/sites-enabled/$applicationName.conf",
			before => Exec["start-server"], 
			require => File["/usr/local/nginx/sites-available/$applicationName.conf"],
		}
		exec { "stop-server":
			path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
  			command => "/usr/sbin/nginx -s stop",
			before => Exec["start-server"],
			onlyif => "/usr/bin/test -f /run/nginx.pid",
			require => File["/usr/local/nginx/sites-available/$applicationName.conf"],
		}
	# env variables for nginx
		file_line { 'nginxstart':
			path => "/etc/init.d/nginxstart",
			line =>"SECRET_KEY_BASE_$appName=`cat $appDirectory/$applicationName/$applicationName/config/.sec.key`",
			require => Exec ["generate-secret"],
		}
		file_line { 'nginxstart export':
			path => "/etc/init.d/nginxstart",
			line =>"export SECRET_KEY_BASE_$appName",
			require => File_line ['nginxstart'],
		}
		file_line{"remove httpd":
			path => "/etc/init.d/nginxstart",
			line => "/usr/sbin/nginx",
			ensure => absent,
			require => [File_line["nginxstart export","nginxstart"], Exec["rake db"]],
		}
		file_line{"add httpd":
			path => "/etc/init.d/nginxstart",
			line => "/usr/sbin/nginx",
			require => File_line["remove httpd"],
		}
		exec { "start-server":
			path => "/usr/local/bin:$path",
			command => "/etc/init.d/nginxstart",
			unless => "/usr/bin/test -f /run/nginx.pid",
			require => [File_line["add httpd"], Exec["link site"]],
		}
	}
##end nginx

##webrick
	if downcase($webserver['name']) =~ /webrick/{
		$initdCommand = $::osfamily ? {
			Debian => "update-rc.d $serverNameStart defaults",
			RedHat => "chkconfig --add $serverNameStart"
		}
		$serverPidFile = "$appDirectory/$applicationName/$applicationName/config/server.pid"
		file{"webrickstart":
			path => "/etc/init.d/$serverNameStart",
			content => "#!/usr/bin/env bash
# chkconfig: 2345 95 20
# processname: $serverNameStart
PATH=/home/$user/.ruby/ruby-$rubyToInstall:/home/$user/.ruby/ruby-$rubyToInstall/bin:/usr/local/bin:$path
export PATH
SECRET_KEY_BASE_$appName=`cat $appDirectory/$applicationName/$applicationName/config/.sec.key`
export SECRET_KEY_BASE_$appName
cd $appDirectory/$applicationName/$applicationName
",
			mode => 755,
			require => Exec["generate-secret"],
			}
		file_line { "$serverNameStart export":
			path => "/etc/init.d/$serverNameStart",
			line =>"export SECRET_KEY_BASE_$appName",
			require => File['webrickstart'],
		}
		file_line { "$serverNameStart add start":
			path => "/etc/init.d/$serverNameStart",
			line =>"/home/$user/.ruby/ruby-$rubyToInstall/bin/rails s -p $port -e production -d -P $serverPidFile",
			require => File_line["$serverNameStart export"],
		}
		exec { "stop-webrick":
			path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
  			command => "kill `cat $serverPidFile`",
			onlyif => "/usr/bin/test -f $serverPidFile",
			before => Exec["start-server"],
		}
		exec { "start-server":
			path => "/home/$user/.ruby/ruby-$rubyToInstall:/home/$user/.ruby/ruby-$rubyToInstall/bin:/usr/local/bin:$path",
  			command => "/etc/init.d/$serverNameStart",
			cwd => "$appDirectory/$applicationName/$applicationName",
			unless => "/usr/bin/test -f $serverPidFile",
			require => [File_line["$serverNameStart add start"], Exec["stop-webrick"], Exec["rake db"]],
			# timeout => 5,
		}
		exec { "add to autostart":
			path => '/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin',
			command => $initdCommand,
			require => File["webrickstart"],
			before => Exec["start-server"],
		}		
	}
##end webrick
}