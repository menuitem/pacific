require 'net/ssh'
require 'net/scp'
require 'io/console'
module Pacific
$psw=[]
class Remote
	# attr_reader :se#, :osFamily, :sshPort,:iP, :identityFile
	attr_accessor :pwd, :setPwd
	def initialize(ip, sshUser, sshPort, identityFile, yamlfile,deploymentUser=@deploymentUser)
		@iP = ip
		@sshUser = sshUser
		@sshPort = sshPort || 22
		@identityFile = identityFile
		@yamlfile = yamlfile
		@deploymentUser = deploymentUser
		@pwd
    end

    def setPwd
		if @pwd.nil? && @identityFile.nil? 
		#decrypt and search in hash
		begin
			if !$psw.empty?
				pswHash = $psw.find{|a| a[:iP]==@iP && a[:sshPort]==@sshPort && a[:sshUser]}
				decipher = OpenSSL::Cipher::AES.new(128, :CBC)
				decipher.decrypt
				decipher.key = pswHash[:key]
				decipher.iv = pswHash[:iv]
				@pwd = decipher.update(pswHash[:pswd]) + decipher.final
			else
			#ask, encrypt and save in hash
				cipher = OpenSSL::Cipher::AES.new(128, :CBC)
				cipher.encrypt
				key = cipher.random_key
				iv = cipher.random_iv
	    		print "#{@iP}:#{@sshPort} #{@sshUser} password: "
				@pwd = psw = STDIN.noecho(&:gets).chomp
				encrypted = cipher.update(psw) + cipher.final
				$psw << {iP: @iP, sshPort: @sshPort, sshUser: @sshUser, pswd: encrypted, key: key, iv: iv}
				print "\n"
			end 
		rescue ArgumentError
			puts "\nNo password was entered."
			exit
		end
		end
    end

	def upload(localPath, remotePath)
		# setPwd
		Net::SSH.start(@iP,@sshUser,:port=>@sshPort,:keys=>@identityFile,:password=>@pwd) do |ssh| 
			ssh.scp.upload(localPath, remotePath, :recursive => true) do |ch, name, sent, total|
  				# puts "#{name}: #{sent}/#{total}"
  				print "."
			end;
		end;
	end
	
	def doTask(tasks,tasksName=nil)
		flag = " Sucessful." 
		print "#{tasksName}" if tasksName
		Net::SSH.start(@iP,@sshUser,:port=>@sshPort,:keys=>@identityFile,:password=>@pwd) do |session| 
			tasks.each do |task|
				t = task[:task]
				m = task[:message]
				print "." if !tasksName.nil?
				print "#{m}" if tasksName.nil?
				result = session.exec!(t)
				flag = "Finished." if !result.nil? && result.include?("Error: ")
				puts "\n#{result}"  if !result.nil? && result.include?("Error: ")
				puts "#{result}"  if task[:output]
				puts " Done."  if task[:message] && !result.nil? && !result.include?("Error: ")
			end;
			print "#{flag}\n" if tasksName
		end;
	end

	def download(localPath, remotePath)
		# setPwd
		Net::SSH.start(@iP,@sshUser,:port=>@sshPort,:keys=>@identityFile,:password=>@pwd) do |ssh| 
			ssh.scp.download(remotePath, localPath, :recursive => true) do |ch, name, sent, total|
  				puts "#{name}: #{sent}/#{total}"
			end;
		end;
	end

	def installPacificGem
		puts "Installing Pacific on #{@iP}:#{@sshPort} machine:"
		folderToCopy = Pacific.gemDirectory + "/pacific"
		destination = "/tmp"
		upload(folderToCopy, destination)
		taskName = "."
		doTask([
		# you can add "output: true" option to every task e.g.: 
		# {task: "sudo mkdir -p /etc/puppet, output: true"}
					{task: "sudo mkdir -p /etc/puppet"},
					{task: "sudo mkdir -p /var/lib/hiera"},
					{task: "sudo cp -rf #{destination}/pacific /usr/local"},
					{task: "sudo cp -f #{destination}/pacific/hiera/hiera.yaml /etc/puppet"},
					{task: "sudo bash /usr/local/pacific/init.sh"},
					{task: "sudo puppet apply /usr/local/pacific/manifests/facter.pp"},
					{task: "rm -rf #{destination}/pacific"},
				], taskName
			)
	end

	def installYaml
		print "Checking #{@yamlfile} ."
		destination = "/tmp"
		upload(@yamlfile, destination)
		taskName = "."
		doTask([{task: "sudo mv -f #{destination}/#{@yamlfile} /var/lib/hiera/pacific.yaml"}], taskName)
	end

end;end