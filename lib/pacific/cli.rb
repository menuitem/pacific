module Pacific
class Cli
	def initialize(yamlObject) 
		@applicationName = yamlObject.applicationName
		@filename = yamlObject.filename
		@sshUser = yamlObject.databaseSshUser || yamlObject.webserverSshUser
		@webserverIP = yamlObject.webserverIP
		@sshPort = yamlObject.webserverSshPort
		@identityFile = yamlObject.databaseIdentityFile || yamlObject.webserverIdentityFile
		@IP = @webserverIP
		@webserverName = yamlObject.webserverName
		@remote = Remote.new(@IP,@sshUser,@sshPort,@identityFile,@filename,@deploymentUser)
		#logs
	end

	def getErrLog
		logs = {
			webrick: "/var/www/#{@applicationName}/#{@applicationName}/log/production.log",
			apache: "/usr/local/apache2/logs/error_log",
			nginx: "/var/log/nginx/error.log"
		}
		log = logs[:"#{@webserverName}"]
		@remote.setPwd if !@remote.pwd
		@remote.doTask([{
			task: "sudo tail -150 #{log} 2>/dev/null",
			message: "#{@webserverIP}:#{@sshPort}:#{log}",
			output: true
		}])
	end
	def pacificApps
		@remote.setPwd if !@remote.pwd
		@remote.doTask([{
			task: "sudo ls /var/www/*/ -d | cut -d'/' -f4 2>/dev/null",
			message: "Apllications on: #{@webserverIP}:#{@sshPort} for #{@filename}",
			output: true
		}])
	end
end;end
