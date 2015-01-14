require "yaml"
module Pacific
class YamlFile
attr_reader :webserverSshPort, :webserverIP, :webserverSshUser, :webserverIdentityFile, :webserverName,
			:databaseSshPort, :databaseIP, :databaseSshUser, :databaseIdentityFile, :databaseName,
			:filename, :rubyVersion, :applicationName, :webserverDeploymentUser, :webserverAppDirectory,
			:nodejsVersion, :webserverVersion, :databaseVersion

def initialize(yamlfileName)
	fd = File.open(yamlfileName,'r')
	yamlObject = YAML::load(fd.read)
	fd.close
	##webserver
	@webserverName = yamlObject["webserver"]["name"]
	@appDirectory = yamlObject["webserver"]["appDirectory"] 
	@webserverVersion = yamlObject["webserver"]["version"]
	@webserverPort = yamlObject["webserver"]["port"]
	@webserverSshUser = yamlObject["webserver"]["sshUser"]
	@webserverIP = yamlObject["webserver"]["IP"]
	@webserverSshPort = yamlObject["webserver"]["sshPort"]
	@webserverDeploymentUser = yamlObject["webserver"]["deploymentUser"]
	@webserverIdentityFile = yamlObject["webserver"]["identityFile"]
	##Database = yamlObject[]
	@databaseName = yamlObject["database"]["name"]
	@databaseVersion = yamlObject["database"]["version"]
	@databasePort = yamlObject["database"]["port"]
	@databaseSshUser = yamlObject["database"]["sshUser"]
	@databaseIP = yamlObject["database"]["IP"]
	@databaseSshPort = yamlObject["database"]["sshPort"]
	@databaseDeploymentUser = yamlObject["database"]["deploymentUser"]
	@databaseIdentityFile = yamlObject["database"]["identityFile"]
	##Common = yamlObject[]
	@filename = yamlfileName
	@applicationName = yamlObject["applicationName"]
	@subURI = yamlObject["subURI"]
	# @osFamily = yamlObject["osFamily"]
	@rubyVersion = yamlObject["rubyVersion"]
	@railsVersion = yamlObject["railsVersion"]
	@nodejsVersion = yamlObject["nodejsVersion"]
end

def self.searchForVersion(file,reg,match="\\d?\\d\\.\\d?\\d\\.\\d?\\d")
	str = ''
	File.open(file, 'r') do |f|
		str = f.grep(/#{reg}/).join().match(/#{match}/).to_s
	   f.close
	end
	str
end

def self.generatePacificYamlfile(filename)
	filename ||= "pacific.yaml"
	cwd = Dir.pwd	
	applicationName = cwd.split('/')[-1].split.join
	# rubyVersion = searchForVersion("Gemfile", "ruby'")
	rubyVersion = `ruby --version`.split(' ')[1].split("p")[0] #if rubyVersion.to_s.empty?
	nodejsVersion = `node -v` || "v0.10.32"
	railsVersion = searchForVersion("Gemfile", "gem 'rails'") 
	File.open(filename, "w")do |f|
	f.write <<-FILE
## Give some information about your deployment. Comment and uncomment settings you need.
applicationName: #{applicationName}
subURI: /
## Specify a web server:
## webrick => name: webrick, port: 80, IP: 127.0.0.1
## Apache => name: apache, version: 2.4.10, port: 80, IP: 127.0.0.1
## Nginx => name: nginx, version: 1.7.2, port: 80, IP: 127.0.0.1
webserver:
  name: webrick
  version: 
  port:
  sshUser:
  IP: 
  sshPort:
  deploymentUser:
  identityFile:
##Specify a database:
## Postgresql => name: postgresql, version: 9.3.5, port: 5432
## Sqlite3 => name: sqlite3  
database:
  name: sqlite3
  version: 
  port: 
  sshUser:
  IP: 
  sshPort:
  deploymentUser:
  identityFile:
##Specify Ruby version
rubyVersion: #{rubyVersion}
##Specify Rails version
railsVersion: #{railsVersion}
##Specify NodeJS Version: ex v0.10.32
nodejsVersion: #{nodejsVersion}
FILE
	  f.close
	end
end
end;end