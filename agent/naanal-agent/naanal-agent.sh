#!/bin/bash

#!/bin/bash

XTRACE=$(set +o | grep xtrace)
set -o xtrace

ERREXIT=$(set +o | grep errexit)
set -o errexit

JAVA_PACKAGE=packages/jdk-8u5-linux-x64.tar.gz
LOGSTASH_PACKAGE=packages/logstash-2.2.0.tar.gz
LOGSTASH_MONASCA_OUTPUT_PACKAGE=packages/logstash-output-monasca_log_api-0.5.gem
ip_pattern="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"

function install_dependency {
	sudo apt-get -y install python-dev
	sudo apt-get -y install python-yaml
	sudo apt-get -y install build-essential
	sudo apt-get -y install libxml2-dev
	sudo apt-get -y install libxslt1-dev
	cp conf/.apache.cnf /root/.apache.cnf
}

function install_agent {
	[ -d "/opt/naanal-agent" ] && sudo rm -r /opt/naanal-agent
	sudo mkdir -p /opt/naanal-agent/
	(cd /opt/naanal-agent ; sudo virtualenv venv)
	(cd /opt/naanal-agent/venv ; sudo ./bin/pip install psutil)
	(cd /opt/naanal-agent/venv ; sudo ./bin/pip install monasca-agent)
	(cd /opt/naanal-agent/venv ; sudo ./bin/pip install python-novaclient)
	(cd /opt/naanal-agent/venv ; sudo ./bin/pip install python-neutronclient)
}
function pre_configuration {

	[ -d "/opt/libvirt" ] && sudo rm -r /opt/libvirt
	mkdir /opt/libvirt
	ln -s /usr/lib/python2.7/dist-packages/libvirt.py /opt/naanal-agent/venv/lib/python2.7/
	ln -s /usr/lib/python2.7/dist-packages/libvirt_lxc.py /opt/naanal-agent/venv/lib/python2.7/
	ln -s /usr/lib/python2.7/dist-packages/libxml2mod.so /opt/naanal-agent/venv/lib/python2.7/
	ln -s /usr/lib/python2.7/dist-packages/libxml2.py /opt/naanal-agent/venv/lib/python2.7/
	ln -s /usr/lib/python2.7/dist-packages/libvirtmod_lxc.x86_64-linux-gnu.so /opt/naanal-agent/venv/lib/python2.7/
	ln -s /usr/lib/python2.7/dist-packages/libvirtmod_qemu.x86_64-linux-gnu.so /opt/naanal-agent/venv/lib/python2.7/
	ln -s /usr/lib/python2.7/dist-packages/libvirtmod.x86_64-linux-gnu.so /opt/naanal-agent/venv/lib/python2.7/
	ln -s /usr/lib/python2.7/dist-packages/libvirt_qemu.py /opt/naanal-agent/venv/lib/python2.7/

}

function start_agent {
	if get_and_validate_ip $0; then
                . /opt/naanal-agent/venv/bin/activate
                monasca-setup --username monasca-agent --password password --project_name mini-mon --keystone_url http://${SERVICE_HOST}:35357/v3 --monasca_url http://${SERVICE_HOST}:8070/v2.0 --skip_detection_plugins Heat
                sudo service monasca-agent stop
	fi
}

function post_configuration {
	chown mon-agent: /opt/libvirt
	rm /opt/naanal-agent/venv/lib/python2.7/site-packages/monasca_agent/common/aggregator.py
        rm /opt/naanal-agent/venv/lib/python2.7/site-packages/monasca_agent/collector/checks_d/libvirt.py
        cp conf/aggregator.py /opt/naanal-agent/venv/lib/python2.7/site-packages/monasca_agent/common/aggregator.py
        cp conf/libvirt.py /opt/naanal-agent/venv/lib/python2.7/site-packages/monasca_agent/collector/checks_d/libvirt.py
        sudo sed -i "s/cache_dir: \/dev\/shm/cache_dir: \/opt\/libvirt/g" /etc/monasca/agent/conf.d/libvirt.yaml
        sudo sed -i "s/nova_refresh: 14400/nova_refresh: 0/g" /etc/monasca/agent/conf.d/libvirt.yaml
	sudo sed -i "s/NAMESPACE/$(ip netns list | grep qrouter)/g" /etc/monasca/agent/conf.d/libvirt.yaml
	sudo service monasca-agent start
	echo "----------------Naanal Agent Started Successfully----------------------------------------"
}

function uninstall {
	. /opt/naanal-agent/venv/bin/activate
	rm -rf /opt/libvirt
	rm -rf /etc/monasca
	rm -rf /var/log/monasca/agent
	rm -rf /opt/naanal-agent
	rm /etc/init.d/monasca-agent
	echo "------------------------------Uninstalled Successfully-------------------------------------"
}

function get_and_validate_ip {
	read -p "What is the Endpoint of Monitoring Node ? (must be ipv4)" SERVICE_HOST
	if [[ $SERVICE_HOST =~ $ip_pattern ]]; then
		return 0 # IP Address is valid
        else
		echo "Oops. Hey... IP is Invalid"
		get_and_validate_ip # Ip Address is Not Valid
	fi    
}

# Check If User run as root

if (( "$EUID" != 0 )); then 
	echo "Please run as root"
	exit
else
	# Check install/uninstall argument is passed
	if [[ $# -eq 1 ]]; then
		if [[ "$1" == "install" ]]; then
			echo "______________________Installing Naanal Agent Dependency__________________________________"
			install_dependency
			echo "_______________________Installing Naanal Agent____________________________________________"
			install_agent
			echo "_______________________PreConfiguring Agent___________________________________________"
			pre_configuration
			echo "_______________________Starting  Agent___________________________________________"
			start_agent
			echo "_______________________Post Configuring Agent___________________________________________"
			post_configuration
                        
		elif [[ "$1" == "uninstall" ]]; then
			echo "_______________________Uninstalling Naanal Log Agent__________________________________________"
			uninstall
		fi
	else
		echo "No Arguments Passed. Run Like ./naanal-agent.sh install or ./naanal-agent.sh uninstall"
		exit
	fi
fi
#Restore errexit
$ERREXIT

# Restore xtrace
$XTRACE
