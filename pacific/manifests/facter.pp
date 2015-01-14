class myFacterVariables{
	file{"/etc/puppet/modules/stdlib/lib/facter/pacific_apache.rb":
		content => "require 'facter'
apacheversion = nil
if FileTest.exists?(\"/usr/local/bin/httpd\")
   	apacheversion =  Facter::Util::Resolution.exec(\"/usr/local/bin/httpd -v\").split(\"/\")[1].split(\" \")[0] || \"undef\"
end
Facter.add(\"apacheversion\") do
    setcode do
        apacheversion
    end
end
"	
	}

	file{"/etc/puppet/modules/stdlib/lib/facter/pacific_nginx.rb":
		content => "require 'facter'
nginxversion = nil
if FileTest.exists?(\"/usr/sbin/nginx\")
   	nginxversion = Facter::Util::Resolution.exec(\"nginx -v 2>&1\").split(\"/\")[1] || \"undef\"
end
Facter.add(\"nginxversion\") do
    setcode do
        nginxversion
    end
end
"	
	}
	file{"/etc/puppet/modules/stdlib/lib/facter/pacific_nodejs.rb":
		content => "require 'facter'
nodejsversion = nil
if FileTest.exists?(\"/usr/local/bin/node\")
   	nodejsversion = Facter::Util::Resolution.exec(\"node --version\") || \"undef\"
end
Facter.add(\"nodejsversion\") do
    setcode do
        nodejsversion
    end
end
"	
	}
	file{"/etc/puppet/modules/stdlib/lib/facter/pacific_passenger_root.rb":
		content => "require 'facter'
passengerroot = nil
passengerroot = Facter::Util::Resolution.exec(\"/usr/local/bin/passenger-config --root\") || \"undef\"
Facter.add(\"passengerroot\") do
    setcode do
		passengerroot
    end
end
"
	}
}
class{"myFacterVariables":}
