#!/bin/bash
####################################################################################################################
# Title           :hadoop_install.sh
# Description     :This script was created for the IU course I535 Management, Access and Use of Big and Complext Data.
# Author	  	  :Utkarsh Kumar, INFO-I 535
# Date            :09/26/2019
# Version         :0.1    
# License	      :The script is distributed under the GPL 3.0 license (http://www.gnu.org/licenses/gpl-3.0.html)
#		   		  You are free to run, study, share and modify this script. 
###################################################################################################################
###################################################################################################################
############################################## CONFGIURATIONS #####################################################
###################################################################################################################

####### Configuration variables ##########
# USER_NAME who should be the owner of HADOOP and run HADOOP
USER_NAME=utkumar

# HADOOP tarball url
HADOOP_TARBALL_URL="http://apache.cs.utah.edu/hadoop/common/hadoop-3.2.1/hadoop-3.2.1.tar.gz"

# Set the location of HADOOP installation directory
HADOOP_HOME_DIR="/opt/hadoop"

# Specify the java to be installed using yum install
JAVA_TYPE="java-1.8.0-openjdk"

# Derived Variables
USER_HOME="/home/$USER_NAME"
BASH_PROFILE="$USER_HOME/.bashrc"
# Outfile
OUT_FILE="$USER_HOME/HADOOP_install.out" 


####### Flags #########
# To start all HADOOP daemons (start-all.sh), set the flag to 1. This flag should only be set if ssh less 
# login has been setup for localhost. Otherwise the start will fail.
RUN_HADOOP_DAEMONS=1

# Other script flags. Not to be changed. 
HADOOP_DOWNLOAD_FLAG=0
JAVA_INSTALL_FLAG=0
HADOOP_INSTALL_FLAG=0
PASSWORDLESS_SSH_FLAG=0

########################################### END OF CONFGIURATIONS #################################################

###################################################################################################################
################################################ FUNCTIONS ########################################################
###################################################################################################################

# Formatted output
function out() 
{
    echo "[${USER}][`date`] - ${*}"
}


# Help function 
function helpFunction()
{
   echo ""
   echo "Usage: $0 -d <dirname>"
   echo -e "\t-d Directory where HADOOP will be installed - HADOOP_HOME. Default is /opt"
   exit 1 
}

# Function to initialize HADOOP_HOME by default
function defaultInit()
{
   out "INFO - HADOOP Home directory not defined. Using default directory /opt/HADOOP to install HADOOP."
   HADOOP_HOME_DIR="/opt/hadoop"
}

# Function to install java
function install_java()
{
	out "INFO - Installing java version 1.8. JAVA TYPE - $JAVA_TYPE"
	command="yum install -y $JAVA_TYPE"
	if $command >> $OUT_FILE; then
		JAVA_VERSION=$(java -version 2>&1 | awk -F '"' 'NR==1 {print $2}')
		JAVA_INSTALL_FLAG=1
		JAVA_HOME_DIR=$(java -XshowSettings:properties -version 2>&1 > /dev/null | grep 'java.home' | awk -F '=' '{print $2}' |  tr -d ' ')
		out "INFO - Installed java 1.8 successfully. JAVA VERSION $JAVA_VERSION"
		out "INFO - Java home directory - $JAVA_HOME_DIR"
	else
		out "ERROR - Failed to install Java. Please install java manually and then rerun the script."
		exit 9
	fi
}

# Function to check if directory exists, if not then create
function check_dir()
{
	if [ ! -d "$1" ]
	then
		out "INFO - Creating directory $1"
		mkdir $1
	else
		out "INFO - $1 already exists."
	fi
}

############################################## END OF FUNCTIONS ####################################################

####################################################################################################################
############################################## MAIN SCRIPT #########################################################
####################################################################################################################

out "INFO - Starting Hadoop Installation Script"
out "INFO - Hadoop URL - $HADOOP_TARBALL_URL"
out "INFO - Java Type - $JAVA_TYPE"
out "INFO - Bash profile file - $BASH_PROFILE"
out "INFO - Using Hadoop directory - $HADOOP_HOME_DIR"

# Check if the user running the script is root or not. Use sudo script to run this script.
out "INFO - Checking if you are a root user."
if [ "$UID" -ne "0" ]; then
    out "WARN - You must be root to run $0. Try - sudo $0"
	out "ERROR - Exiting script."
    exit 9
fi

# Check if java is installed or not. If not, install java using install java function.
if type -p java >> $OUT_FILE; then
	JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F '.' '{print $1"."$2}')
	if [[ "$JAVA_VERSION" == "1.8" ]]; then
		out "INFO - Java version 1.8 is already installed. JAVA VERSION $JAVA_VERSION"
		JAVA_HOME_DIR=$(java -XshowSettings:properties -version 2>&1 > /dev/null | grep 'java.home' | awk -F '=' '{print $2}' |  tr -d ' ')
		out "INFO - Java home directory - $JAVA_HOME_DIR"
		JAVA_INSTALL_FLAG=1
	elif [[ "$JAVA_VERSION" == "" ]]; then
		install_java
	else
		out "WARN - Java version is not 1.8. JAVA VERSION $JAVA_VERSION"
		install_java
	fi
else
	install_java
fi

# Download Hadoop tarball and extract to HADOOP_HOME
if [[ $JAVA_INSTALL_FLAG -eq 1 ]]; then
	out "INFO - Downloding Hadoop tarball from - $HADOOP_TARBALL_URL"
	command="wget -O /tmp/hadoop.tgz $HADOOP_TARBALL_URL"
	if $command >> $OUT_FILE; then
		out "INFO - Hadoop tarball download complete"
		HADOOP_DOWNLOAD_FLAG=1
		if check_dir "$HADOOP_HOME_DIR"; then 
			out "INFO - Extracting Hadoop tarball to $HADOOP_HOME_DIR"
			command="tar -zxf /tmp/hadoop.tgz --directory $HADOOP_HOME_DIR --strip-components=1"
			if $command >> $OUT_FILE; then
				HADOOP_INSTALL_FLAG=1
				out "INFO - Hadoop tarball successfully downloaded and extracted."
				rm /tmp/hadoop.tgz
				out "INFO - Changing ownership of $HADOOP_HOME_DIR"
				chown -R $USER_NAME:$USER_NAME $HADOOP_HOME_DIR
			else
				out "ERROR - Failed to extract Hadoop tarball"
				exit 9
			fi
		else
			out "ERROR - Failed to create Hadoop home directory."
			exit 9
		fi
	else
		out "ERROR - Failed to download Hadoop."
		exit 9
	fi
else
	out "ERROR - Java is not installed. Exiting script."
	exit 9
fi


# Create password-less ssh login to localhost
out "INFO - Checking public key"
PUBLIC_KEY_FILE="/home/$USER_NAME/.ssh/id_rsa.pub"
AUTHORIZED_KEY_FILE="/home/$USER_NAME/.ssh/authorized_keys"
if test -f "$PUBLIC_KEY_FILE"; then
    out "INFO - Public key already exists."
	PUBLIC_KEY_CONTENT=$(cat $PUBLIC_KEY_FILE)
	if ! grep --quiet -f $PUBLIC_KEY_FILE $AUTHORIZED_KEY_FILE; then
		echo $PUBLIC_KEY_CONTENT >> $AUTHORIZED_KEY_FILE
		PASSWORDLESS_SSH_FLAG=1
		out "INFO - Copied content of public key to authorized keys."
	else
		out "INFO - Content of public key  already present in authorized keys."
		PASSWORDLESS_SSH_FLAG=1
	fi
else
	out "INFO - Creating private and public keys"
	su -c 'cat /dev/zero | ssh-keygen -q -N ""' - $USER_NAME
	if [ $? -eq 0 ]; then
		PUBLIC_KEY_CONTENT=$(cat $PUBLIC_KEY_FILE)
		echo $PUBLIC_KEY_CONTENT >> $AUTHORIZED_KEY_FILE
		PASSWORDLESS_SSH_FLAG=1
		out "INFO - Copied content of public key to authorized keys."
	else
		out "WARN - Could not create private and public key. Please manually create key pair and copy the content of public key to authorized_keys."
	fi
fi


# Add HADOOP_HOME to bash profile
out "INFO - Adding HADOOP_HOME to bash profile - $BASH_PROFILE"
if ! grep -Fxq "export HADOOP_HOME=$HADOOP_HOME_DIR" $BASH_PROFILE; then
	echo "export HADOOP_HOME=$HADOOP_HOME_DIR" >> $BASH_PROFILE
fi
if ! grep -Fxq 'export PATH=$HADOOP_HOME/bin:$PATH' $BASH_PROFILE; then
	echo 'export PATH=$HADOOP_HOME/bin:$PATH' >> $BASH_PROFILE
fi

# Export JAVA_HOME 
if ! grep -Fxq "export JAVA_HOME=$JAVA_HOME_DIR" $BASH_PROFILE; then
	echo "export JAVA_HOME=$JAVA_HOME_DIR" >> $BASH_PROFILE
fi

# Replace core-site and hdfs-site xml files
out "INFO - Replacing core-site.xml file"
cat > $HADOOP_HOME_DIR/etc/hadoop/core-site.xml <<'_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
</configuration>
_EOF

out "INFO - Replaced core-site.xml file"
out "INFO - Replacing hdfs-site.xml file"

cat > $HADOOP_HOME_DIR/etc/hadoop/hdfs-site.xml <<'_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
</configuration>
_EOF
out "INFO - Replaced hdfs-site.xml file"

# Start Hadoop daemons if flag is set.
if [ $RUN_HADOOP_DAEMONS -eq 1 ] && [ $PASSWORDLESS_SSH_FLAG -eq 1 ]; then 
	out "INFO - Starting Hadoop daemons."
	export PATH=$JAVA_HOME_DIR/bin:$PATH;
	export PATH=$HADOOP_HOME/bin:$PATH;
	command="su - $USER_NAME $HADOOP_HOME_DIR/bin/hdfs namenode -format"
	if $command >> $OUT_FILE; then
		out "INFO - Namenode format complete."
	else
		out "WARN - Error formatting namenode."
	fi
	command="su - $USER_NAME $HADOOP_HOME_DIR/sbin/start-dfs.sh"
	out "INFO - COMMAND - $command"
	if $command >> $OUT_FILE; then
		out "INFO - Hadoop daemons started."
	else
		out "WARN - Error starting Hadoop daemons."
	fi
fi


out "INFO - End of HADOOP installation script."
############################################## END OF MAIN SCRIPT ###################################################
