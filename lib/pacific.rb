require "pacific/version"
require "pacific/etc"
require "pacific/pacificyaml"
require "pacific/remote"
require "pacific/webserver"
require "pacific/database"
require "pacific/deploy"
require "pacific/cli"
module Pacific
# what need to be done
# generate yaml file and check and validate its content # pacific init
# get script to the server  
# install git and create repository
# push project to server
# run the deployment script
# just one yaml config but two deifferent classes
# asynchronous upload; call returns immediately and requires SSH
def Pacific.readCommandParams
begin
	yamlfile = ARGV[1] || "pacific.yaml"
	if ARGV[0].to_s.empty?
		Pacific.pacific
	elsif ARGV[0].to_s.match /init/i
		Pacific.validateProject
		Pacific.init(yamlfile)
	elsif ARGV[0].to_s.match /dbm/i
		Pacific.validateFilePresence(yamlfile)
		yamlFile = YamlFile.new(yamlfile)
		Pacific.validateFilePresence("Gemfile") if !yamlFile.applicationName.nil?
		Pacific.validateProject if !yamlFile.applicationName.nil?
		Deploy.new(DeployWebServer.new(yamlFile),DeployDatabase.new(yamlFile)).deployBareMetal
	elsif ARGV[0].to_s.match /deploy/i
		Pacific.validateFilePresence(yamlfile)
		yamlFile = YamlFile.new(yamlfile)
		Pacific.validateFilePresence("Gemfile")
		Pacific.validateProject
		Deploy.new(DeployWebServer.new(yamlFile),DeployDatabase.new(yamlFile)).deploy
	elsif ARGV[0].to_s.match /log/i
		Pacific.validateFilePresence(yamlfile)
		Pacific.validateProject
		log = Cli.new(YamlFile.new(yamlfile))
		log.getErrLog
	elsif ARGV[0].to_s.match /apps/i
		Pacific.validateFilePresence(yamlfile)
		Pacific.validateProject
		apps = Cli.new(YamlFile.new(yamlfile))
		apps.pacificApps
	elsif ARGV[0].to_s.eql? "-v"
		puts VERSION
	else 
		puts "I dn't know what do you want!"
	end
rescue Interrupt => e
	puts " ...Ouch!"
rescue Timeout::Error
    puts  " ...Timed out"
    exit
rescue Errno::EHOSTUNREACH
    puts  " ...Host unreachable"
    exit
rescue Errno::ECONNREFUSED
    puts  " ...Connection refused"
    exit
rescue Net::SSH::AuthenticationFailed
    puts  " ...Authentication failure"
    exit
end
end;end