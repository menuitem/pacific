require 'open3'
module Pacific

# Pacific.run will run commands on local machine. Open3 library helps to catch exceptions.
def Pacific.run(command, options={})
	Open3.popen3(command) do |i, o, e, w|
		print "#{options[:message]}" if options[:message]
		puts "\'#{command}\' executed successfully." if w.value.success? && options[:log]
		puts "\'#{command}\' failed." if !w.value.success? && options[:log]
		puts " Done." if options[:message] && w.value.success?
		output =o.read.chomp if options[:stdout]
	end
end

# Pacific.gemDirectory gets pacific instalation directory.
def Pacific.gemDirectory
	pacificDir = File.dirname(__FILE__).split("/")
	pacificDir.delete_at(-1)
	pacificDir.delete_at(-1)
	pacificDir.join("/")
end

# Generates deployment configuration file. 'pacific.yaml' by default.
def Pacific.init(filename)
	if File.exists? filename
		Pacific.validateFilePresence('Gemfile')
		puts "File #{filename} already exists. If you continue the file will be overvwritten."
		print "Do you want to continue? (y/n) "
		answer = STDIN.gets.chomp 
		if answer.downcase.eql? "yes" or answer.downcase.eql? "y"
			YamlFile.generatePacificYamlfile(filename)
			puts "File #{filename} changed successfully."
		else
			puts "File #{filename} not changed."
		end
	else
		YamlFile.generatePacificYamlfile(filename)
		puts "File #{filename} generated successfully."
	end
end

# Pacific.pacific displays info about pacific gem.
# ¸¸.•*¨*•.٩(͡๏̯͡๏)۶.¸¸¸.•*¨*•.¸¸¸.•*¨*•.¸¸¸.•*¨*•.¸¸¸.•*¨*•.¸¸¸.•*¨*•.¸.•*
# ¨*•.¸¸.•*¨*•.¸¸¸.•*¨*•.¸¸¸.•*¨*•.¸¸¸.•*¨*•.٩(͡๏̯͡๏)۶.¸¸¸.•*¨*•.¸¸¸.•*¨*•.¸
# ¸¸.•*¨*•.¸¸¸.•*¨*•.٩(͡๏̯͡๏)۶.¸¸¸.•*¨*•.¸¸¸.•*¨*•.¸¸¸.•*¨*•.¸¸¸.•*¨٩(͡๏̯͡๏)۶
def Pacific.pacific
	puts <<-FILE 

Usage: pacific COMMAND [arg...]

A self sufficient deployment system for rails applications.

Commands:
  init      [filename] Generate configuration file -> pacific.yaml.
  dbm       [filename] Deploy bare metal. Run full bare metal deployment. 
  deploy    [filename] Bring your app to the next level.
  apps      [filename] Displays applications on webserver specified in configuration file.
  log       [filename] Displays log on webserver specified in configuration file.
Args:
  [filename] Deployment configuration file. Default: pacific.yaml
  Version: #{VERSION}
FILE
end

# Pacific.validateProject checks out if we are in the rails project root.	
def Pacific.validateProject
	flag = true
	flag = false if !File.exists? "public" 
	flag = false if !File.exists? "Gemfile"
	flag = false if !File.exists? "config.ru" 
	puts "Make sure you are in your project directory." if !flag
	exit if !flag
end

def Pacific.validateFilePresence(file)
	if !File.exists? file
		puts "You need #{file} file."
		# exit
	end
end;end