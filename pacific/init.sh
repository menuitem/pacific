#!/bin/bash
#install ruby via rvm, facter, puppet
#checking for os family
function installOnDebian
{
  echo "Checking for puppet..."
  puppetInstalled=$(sudo aptitude show puppet | grep State)
  log="puppet $puppetInstalled"
  if [ "$puppetInstalled" = "State: installed" ]; then
    echo $log
  else
  sudo apt-get install lsb-release -y  
    printf "Installing puppet..."
    cd /tmp
    wget https://apt.puppetlabs.com/puppetlabs-release-stable.deb
    sudo dpkg -i puppetlabs-release-stable.deb
    sudo apt-get update
    sudo apt-get -y install puppet
    sudo apt-get -y install rubygems
    if [ "$?" -eq 0 ]; then
      printf " Success\n"
      echo "Installing puppet ... Success"
      rm -f /tmp/puppetlabs-release-stable.deb
    else
      printf " Error\n"
      echo "Installing puppet... Error" #| tee -a $deploymentLog 
    fi
  fi
}
############################################################
function installOnRedhat
{
  echo "Checking for puppet..."
  sudo yum -y install redhat-lsb
  osRelease=`lsb_release -r | cut -d: -f2 |cut -d. -f1|xargs` # => 4, 5, 6 or 7
  puppetInstalled=$(rpm -qa | grep puppet)
  if [ "$?" = 0 ]; then
    log="puppet $puppetInstalled"
    echo $log
  else
    printf "Installing puppet..."
    sudo yum -y update
    sudo rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-el-"$osRelease".noarch.rpm
    sudo yum -y install puppet
    sudo yum -y install rubygems
    if [ "$?" -eq 0 ]; then
      printf " Success\n"
      echo "Installing puppet ... Success" #>>$deploymentLog
      rm -f /tmp/puppetlabs-release-stable.deb
    else
      printf " Error\n"
      echo "Installing puppet... Error" #| tee -a $deploymentLog 
    fi
  fi
}
####################################################################

#INSTALL PUPPET
if [ -f /etc/debian_version ] ; then
  installOnDebian
elif [ -f /etc/redhat-release ] ; then
  installOnRedhat
fi
####################################################

# install stdlib module
stdlibModul=`sudo puppet module list | grep "puppetlabs-stdlib"`
if [ "$stdlibModul" ]; then
  echo  "Stdlib is installed already"
else
  sudo puppet module install puppetlabs-stdlib
fi
