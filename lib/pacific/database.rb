module Pacific
class DeployDatabase
def initialize(yamlObject)
	@applicationName = yamlObject.applicationName
	@filename = yamlObject.filename
	@sshUser = yamlObject.databaseSshUser || yamlObject.webserverSshUser
	@webserverIP = yamlObject.webserverIP
	@databaseIP = yamlObject.databaseIP || @webserverIP
	@databaseName = yamlObject.databaseName #|| "sqlite3"
	@sshPort = yamlObject.databaseSshPort || yamlObject.webserverSshPort
	@identityFile = yamlObject.databaseIdentityFile || yamlObject.webserverIdentityFile
	@IP = @databaseIP || @webserverIP
	@databaseVersion = yamlObject.databaseVersion
	@remote = Remote.new(@IP,@sshUser,@sshPort,@identityFile,@filename,@deploymentUser)
end

def deployDatabase
	@remote.setPwd if !@remote.pwd
	if @applicationName
		@remote.installYaml
		# @remote.installPacificGem #remove it
		$pacificBranch = Pacific.run("git branch | grep \\* | cut -d\" \" -f2", stdout: true)
		$pacificBranch = false if $pacificBranch.match(/detached/)
		$pacificCurrentCommit = Pacific.run("git rev-parse HEAD", stdout: true)
		puts "\e[0;31mWarning:\e[m You are currently off B R A N C H !!!.\nIgnore this warning if you have reference #{$pacificCurrentCommit} upstream. Ctrl + c to stop." if !$pacificBranch
		puts "Deploying branch:\e[1;34m #{$pacificBranch}\e[m" if $pacificBranch
		tasks = []
		tasks << {tasks: "sudo puppet apply /usr/local/pacific/manifests/postgresusers.pp",
			message: "Preapring database for #{@applicationName}."} if @databaseName && @databaseName.include?("postgres")
		tasks << {task: "sudo puppet apply /usr/local/pacific/manifests/sqlite3.pp",
			message: "Checking for sqlite3..."} if @databaseName && @databaseName.include?("sqlite")
		@remote.doTask(tasks) if !tasks.empty?
		@remote.download("/var/lib/postgresql/.#{@applicationName}AppPass","/var/www/#{@applicationName}/#{@applicationName}/config/.#{@applicationName}AppPass") if @databaseIP != @webserverIP
	end
end

def deployBareMetal
	@remote.setPwd if !@remote.pwd
	@remote.installPacificGem @databaseIP if @databaseIP != @webserverIP
	tasks = []
	tasks << {task: "sudo puppet apply /usr/local/pacific/manifests/postgresql.pp",
		message: "Installing postgresql #{@databaseVersion}. Please, wait."} if @databaseName && @databaseName.include?("postgres")
	tasks << {task: "sudo puppet apply /usr/local/pacific/manifests/sqlite3.pp",
		message: "Installing sqlite3."} if @databaseName && @databaseName.include?("sqlite")
	@remote.doTask(tasks) if !tasks.empty?
end
end;end	