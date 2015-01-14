module Pacific
class Deploy

def initialize(webserver, database)
	@webserver = webserver
	@database = database
end

def deployBareMetal
	t1=Time.now
	@webserver.deployBareMetal
	@database.deployBareMetal 
	@database.deployDatabase
	@webserver.deployApplication
	t2=Time.now
	puts "Time: #{(t2-t1).to_i}s"
end

def deploy
	t1=Time.now
	@database.deployDatabase
	@webserver.deployApplication
	t2=Time.now
	puts "Time: #{(t2-t1).to_i}s"
end
end;end