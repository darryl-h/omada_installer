#!/bin/bash
#
# Initial Concept: Darryl H (https://github.com/darryl-h)
# Maintainer: Darryl H (https://github.com/darryl-h)
# Purpose: Installs the Omada Controller in Ubuntu 20.04 as per the
#          instructions at https://www.tp-link.com/ca/support/faq/3272/

# Define the version
Version=0.0009
# Define the log file
LogFile=~/Omada-Install.log
# Define colors
ColorRed='\033[0;31m'
ColorGreen='\033[0;32m'
ColorReset='\033[0m'

# Ancillary Functions
function WriteMessage () {
  local timenow=$(date +"%T")
  if [ $1 = "OK" ] ; then
    printf "[%s |${ColorGreen}%-8.8s${ColorReset}| %-57.57s]\n" "$timenow" "$1" "$2"
  elif [ $1 = "ERROR" ] ; then
    printf "[%s |${ColorRed}%-8.8s${ColorReset}| %-57.57s]\n" "$timenow" "$1" "$2"
  elif [ $1 = "DEBUG" ] ; then
    :
  else
    printf "[%s |%-8.8s| %-57.57s]\n" "$timenow" "$1" "$2"
  fi
  echo "====[]$(date) - ${2}" >> ${LogFile}
}

function DownloadFile () {
    which wget >> ${LogFile} 2>&1
    if [ $? -ne 0 ] ; then
        WriteMessage "  ERROR" "This machine does not have wget installed! Please install it."
        exit 1
    fi
    local DownloadURL=$1
    local DownloadFile=$2
    WriteMessage "DOWNLOAD" "Downloading ${DownloadFile}"
    wget --tries=1 --output-document=/tmp/${DownloadFile} ${DownloadURL}/${DownloadFile} >> ${LogFile} 2>&1
    if [ $? -ne 0 ] ; then
        WriteMessage "  ERROR" "Networking : Failed to download ${DownloadFile}"
        echo "    Suggestion: Please verify local network and internet connectivity to:"
        echo "                ${DownloadURL}"
        exit 1
    else
        WriteMessage "   OK" "Downloaded ${DownloadFile}"
    fi
}

function AptInstall () {
  WriteMessage "  APT" "Installing ${1}"
  DEBIAN_FRONTEND=noninteractive apt-get install --quiet --assume-yes ${1} >> ${LogFile} 2>&1
  if [ $? -ne 0 ] ; then
    WriteMessage "  ERROR" "Apt : Failed to install ${1}"
    echo "    Suggestion: Please verify local network and internet connectivity to system repositories"
    exit 1
  else
    WriteMessage "   OK" "Installed ${1}"
  fi
}

cat << EOF
████████╗██████╗       ██╗     ██╗███╗   ██╗██╗  ██╗     ██████╗ ███╗   ███╗ █████╗ ██████╗  █████╗ 
╚══██╔══╝██╔══██╗      ██║     ██║████╗  ██║██║ ██╔╝    ██╔═══██╗████╗ ████║██╔══██╗██╔══██╗██╔══██╗
   ██║   ██████╔╝█████╗██║     ██║██╔██╗ ██║█████╔╝     ██║   ██║██╔████╔██║███████║██║  ██║███████║
   ██║   ██╔═══╝ ╚════╝██║     ██║██║╚██╗██║██╔═██╗     ██║   ██║██║╚██╔╝██║██╔══██║██║  ██║██╔══██║
   ██║   ██║           ███████╗██║██║ ╚████║██║  ██╗    ╚██████╔╝██║ ╚═╝ ██║██║  ██║██████╔╝██║  ██║
   ╚═╝   ╚═╝           ╚══════╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝     ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝
                                                                                  Version ${Version}
EOF

# Ensure we have permissions to install software
if [[ ${EUID} -ne 0 ]] ; then
  WriteMessage "  ERROR" "Credentials : This script requires elevated permissions!"
  exit 1
fi

# Validate that we are running in Ubuntu 20
if [ -f /etc/os-release ] ; then
    if [ $(grep ^ID= /etc/os-release | awk -F= '{print $2}' | sed 's/"//g') = "ubuntu" ] ; then
        if [ $(grep ^VERSION_ID= /etc/os-release | awk -F= '{print $2}' | sed 's/"//g' | awk -F. '{print $1}') = 20 ] ; then
            WriteMessage "   OK" "Detected Ubuntu 20.x"
            os_version=ubuntu18
        else
            WriteMessage "  ERROR" "Unsupported Ubuntu Distribution!"
            exit 1
        fi
    else
        WriteMessage "  ERROR" "Unsupported Linux Distribution!"
        exit 1
    fi
else
    WriteMessage "  ERROR" "Missing /etc/os-release file!"
fi

# Make sure the system is capable of installing software
WriteMessage VALIDATE "Verifying apt status"
AptRunning=$(fuser /var/lib/dpkg/lock 2>&1 | wc -l)
if [ $AptRunning -gt 0 ] ; then
    WriteMessage "  ERROR" "It looks like there's an apt process in progress" 
    echo "    Suggestion: Retry in a few minutes"
    exit 1
else
    WriteMessage "   OK" "apt doesn't appear to be in use"
fi
WriteMessage "  APT" "Updating apt system repos"
apt-get update >> ${LogFile} 2>&1
if [ $? -ne 0 ] ; then
    WriteMessage "  ERROR" "Could not update system repos!"
    echo "    Suggestion: Please verify apt sources are still valid"
    exit 1
else
    WriteMessage "   OK" "apt system repos have been updated"
fi

# Install openjdk-11-jre-headless
AptInstall openjdk-11-jre-headless

# Install the GPG key
wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add - >> ${LogFile} 2>&1

# Update the Apt Repos
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list >> ${LogFile} 2>&1
apt update >> ${LogFile} 2>&1

# Install MongoDB
AptInstall mongodb-org

# Install jsvc
AptInstall jsvc

# Download the Omada package
DownloadFile https://static.tp-link.com/upload/software/2022/202201/20220120 Omada_SDN_Controller_v5.0.30_linux_x64.deb

# Install Omada Controller
WriteMessage "INSTALL" "Installing the Omada software"
dpkg --ignore-depends=jsvc -i /tmp/Omada_SDN_Controller_v5.0.30_linux_x64.deb
