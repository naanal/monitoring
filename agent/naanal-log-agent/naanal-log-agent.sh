#!/bin/bash

XTRACE=$(set +o | grep xtrace)
set -o xtrace

ERREXIT=$(set +o | grep errexit)
set -o errexit

JAVA_PACKAGE=packages/jdk-8u5-linux-x64.tar.gz
LOGSTASH_PACKAGE=packages/logstash-2.2.0.tar.gz
LOGSTASH_MONASCA_OUTPUT_PACKAGE=packages/logstash-output-monasca_log_api-0.5.gem
ip_pattern="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"

function install_dependency  {
	java -version || install_java
}

function install_java {
	[ -d "/opt/jdk" ] && sudo rm -r /opt/jdk
	sudo mkdir /opt/jdk
	sudo tar -zxf "${JAVA_PACKAGE}" -C /opt/jdk
        update-alternatives --install /usr/bin/java java /opt/jdk/jdk1.8.0_05/bin/java 100
        update-alternatives --install /usr/bin/javac javac /opt/jdk/jdk1.8.0_05/bin/javac 100
#	apt-get install default-jdk
        java -version	
}

function install_log_agent {
	sudo tar xzf "${LOGSTASH_PACKAGE}" -C /opt
	sudo ln -sf /opt/logstash-2.2.0 /opt/logstash
	sudo cp -f "${LOGSTASH_MONASCA_OUTPUT_PACKAGE}" /opt/logstash/
	sudo /opt/logstash/bin/plugin install /opt/logstash/logstash-output-monasca_log_api-0.5.gem
	echo "Naanal Log Agent Installed Succesfully"
}

function configure_log_agent {

	# Create group and add seperate user for monasca log agent
	getent group monasca || sudo groupadd monasca
	sudo useradd --system -g monasca mon-log-agent || true

	# Create Log Folder
	sudo mkdir -p /var/log/monasca/monasca-log-agent || true
	sudo chown mon-log-agent:monasca /var/log/monasca/monasca-log-agent
	sudo chmod 0750 /var/log/monasca/monasca-log-agent


	sudo mkdir -p /etc/monasca/monasca-log-agent || true
	sudo chown mon-log-agent:monasca /etc/monasca/monasca-log-agent
	sudo chmod 0750 /etc/monasca/monasca-log-agent
	
	# Copy Sample Configuration
	sudo cp -f conf/agent.conf /etc/monasca/monasca-log-agent/agent.conf
	sudo chown mon-log-agent:monasca /etc/monasca/monasca-log-agent/agent.conf
	sudo chmod 0640 /etc/monasca/monasca-log-agent/agent.conf
	
	# Get The IP Address of Monitoring Node. 	
	
	if get_and_validate_ip $0; then
		sudo sed -i \
			"s/monasca_log_api_url => \"http:\/\/127\.0\.0\.1:5607/monasca_log_api_url => \"http:\/\/${SERVICE_HOST}:5607/g" \
			/etc/monasca/monasca-log-agent/agent.conf

		  sudo sed -i \
                        "s/keystone_api_url => \"http:\/\/127\.0\.0\.1:35357/keystone_api_url => \"http:\/\/${SERVICE_HOST}:35357/g" \
                        /etc/monasca/monasca-log-agent/agent.conf

        fi
	
	sudo cp -f conf/monasca-log-agent.conf /etc/init/monasca-log-agent.conf
	sudo chown mon-log-agent:monasca /etc/init/monasca-log-agent.conf
	sudo chmod 0640 /etc/init/monasca-log-agent.conf

	# Start the Service
	sudo start monasca-log-agent || sudo restart monasca-log-agent
	echo "Congrats!!! Naanal Log Agent Installed and Configured Succesfully"
}


function uninstall {
    
    sudo rm -rf /var/log/monasca/monasca-log-agent
    sudo rm -rf /etc/monasca/monasca-log-agent
    sudo rm -f /etc/init/monasca-log-agent.conf
    sudo rm -rf /opt/logstash
    sudo rm -rf /opt/logstash-2.2.0
    sudo userdel mon-log-agent || true
    echo "Congrats!!! Naanal Log Agent Successfully Uninstalled"
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

if [[ $# -eq 1 ]];
 then
	if [[ "$1" == "install" ]]; then
		echo "______________________Installing Naanal Log Agent Dependency__________________________________"
		install_dependency
		echo "_______________________Installing Naanal Log Agent____________________________________________"
		install_log_agent
		echo "_______________________Configuring Naanal Log Agent___________________________________________"
		configure_log_agent
	elif [[ "$1" == "uninstall" ]]; then
		echo "_______________________Uninstalling Naanal Log Agent__________________________________________"
		uninstall
	fi
 else
	echo "No Arguments Passed. Run Like ./naanal-log-agent.sh install or ./naanal-log-agent.sh uninstall"
fi
#Restore errexit
$ERREXIT

# Restore xtrace
$XTRACE
