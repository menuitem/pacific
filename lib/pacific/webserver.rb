module Pacific
class DeployWebServer

def initialize(yamlObject)
	@applicationName = yamlObject.applicationName
	@appDirectory = yamlObject.webserverAppDirectory || "/var/www"
	@rubyVersion = yamlObject.rubyVersion		
	@webserverName = yamlObject.webserverName
	@filename = yamlObject.filename
	@sshUser = yamlObject.webserverSshUser
	@webserverDeploymentUser = yamlObject.webserverDeploymentUser
	@deploymentUser = @webserverDeploymentUser || @sshUser
	@webserverIP = yamlObject.webserverIP
	@databaseIP = yamlObject.databaseIP || @webserverIP
	@sshPort = yamlObject.webserverSshPort
	@identityFile = yamlObject.webserverIdentityFile
	@nodejsVersion = yamlObject.nodejsVersion
	@webserverVersion = yamlObject.webserverVersion 
	@remote = Remote.new(@webserverIP,@sshUser,@sshPort,@identityFile,@filename,@deploymentUser)
end

def deployApplication
	@remote.setPwd
	if @applicationName
		@remote.installYaml if @databaseIP != @webserverIP
		if @identityFile && @webserverDeploymentUser 
			Pacific.run "ssh-keygen -y -f #{@identityFile} > #{@deploymentUser}.pub"
			@remote.upload("#{@deploymentUser}.pub", "/tmp") if @identityFile
		elsif !@identityFile
			pubkey = Pacific.run(" ls ~/.ssh/ |grep .pub |head -n 1", stdout: true)
			@remote.upload("/home/#{ENV['USER']}/.ssh/#{pubkey}", "/tmp/#{@deploymentUser}.pub") if pubkey
		end
		filename = @filename.split('.')[0] #for git remote name
		@remote.doTask([
			{task: "sudo puppet apply /usr/local/pacific/manifests/gitrepo.pp",
				message: "Processing remote repository.",
				ok: true}])
		Pacific.run("git remote remove #{filename}")
		Pacific.run("git remote add #{filename} ssh://#{@deploymentUser}@#{@webserverIP}:#{@sshPort}#{@appDirectory}/#{@applicationName}/#{@applicationName}.git",
			message: "Adding git remote upstream '#{filename}'.")
		Pacific.run("ssh-add #{@identityFile}", message: "Adding to known hosts...") if @identityFile
		Pacific.run("git push -f #{filename} #{$pacificBranch}", message: "Pushing current branch to #{@webserverIP}.") if $pacificBranch
		tasks = []
		tasks << {task: "sudo echo \"branch: #{$pacificBranch}\" >> /var/lib/hiera/pacific.yaml"} if $pacificBranch
		tasks << {task: "sudo echo \"currentCommit: #{$pacificCurrentCommit}\" >> /var/lib/hiera/pacific.yaml"}
		tasks << {task: "sudo puppet apply /usr/local/pacific/manifests/deploy.pp"}
		@remote.doTask(tasks, "Restarting server .") if !tasks.empty?
	end
end

def deployBareMetal
	@remote.setPwd if !@remote.pwd
	@remote.installPacificGem
	@remote.installYaml
	tasks = []
	tasks << {task: "sudo puppet apply /usr/local/pacific/manifests/nodejs.pp",
		message: "Installing node.js: #{@nodejsVersion}. Please, wait."} unless @nodejsVersion.nil?
	tasks << {task: "sudo puppet apply /usr/local/pacific/manifests/ruby.pp",
		message: "Installing ruby #{@rubyVersion}. Please, wait."} unless @rubyVersion.nil?
	tasks << {task: "sudo puppet apply /usr/local/pacific/manifests/passenger.pp",
		message: "Installing passenger gem. Please, wait."} if @webserverName && @webserverName.downcase.include?("nginx")
	tasks << {task: "sudo puppet apply /usr/local/pacific/manifests/passenger.pp",
		message: "Installing passenger gem. Please, wait."} if @webserverName && @webserverName.downcase.include?("apache")
	tasks << {task: "sudo puppet apply /usr/local/pacific/manifests/apache.pp",
		message: "Installing apache #{@webserverVersion}. Please wait."} if @webserverName && @webserverName.downcase.include?("apache")
	tasks << {task: "sudo puppet apply /usr/local/pacific/manifests/nginx.pp",
		message: "Installing nginx #{@webserverVersion}. Please wait."} if @webserverName && @webserverName.downcase.include?("nginx")
	@remote.doTask(tasks)
end
end;end