#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
  echo "This script requires sudo privileges. Please enter your password:"
  exec sudo "$0" "$@" # This re-executes the script with sudo
fi

# setup variables
export SCRIPT_EXPIRATION=scriptexpiration
export JWT_TOKEN=jwttoken

export DEBIAN_FRONTEND=noninteractive

sudo apt update 

if dpkg --get-selections | grep -q "unattended-upgrades"; then
  echo "unattended-upgrades is installed. removing it"
  sudo apt-get remove -y --purge unattended-upgrades
else
  echo "unattended-upgrades is not installed. Nothing to do."
fi

install_tools_utilities() {
  REQUIRED_PKG=$1
  PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG | grep "install ok installed")
  echo -e "\e[37mChecking for $REQUIRED_PKG if it is already installed. \e[73m"
  if [ "" = "$PKG_OK" ]; then
    echo -e "\e[31m  No $REQUIRED_PKG is found on the server. \e[13m\e[32m$REQUIRED_PKG installed. \e[23m \n"
    sudo apt --yes install $REQUIRED_PKG &>/dev/null
  else
    echo -e "\e[32m  $REQUIRED_PKG is already installed on the server/machine.  \e[23m \n"
  fi
}

check_port_443() {
  PORT=443
  command -v netstat >/dev/null 2>&1 || {
    echo >&2 "netstat command not found. Exiting."
    exit 1
  }

  if netstat -tulpn | grep ":$PORT" >/dev/null; then
    echo "Port $PORT is in use."
    echo "Please stop the process running on port $PORT and run the script again"
    exit 1
  else
    echo "Port $PORT is not in use."
  fi
}

install_tools_utilities unzip
install_tools_utilities curl
install_tools_utilities containerd
install_tools_utilities docker.io
install_tools_utilities systemd
install_tools_utilities "systemd-timesyncd"
install_tools_utilities ufw
install_tools_utilities ntp
install_tools_utilities ntpdate
install_tools_utilities net-tools
install_tools_utilities python3
install_tools_utilities jq

#Setting latest docker image wrt latest release
export DOCKER_IMAGE=$(curl -s https://registry.hub.docker.com/v2/repositories/0chaindev/blobber/tags?page_size=100 | jq -r '.results[] | select(.name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | .name' | sort -V | tail -n 1)
export DOCKER_IMAGE_EBLOBBER=$(curl -s https://registry.hub.docker.com/v2/repositories/0chaindev/eblobber/tags?page_size=100 | jq -r '.results[] | select(.name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | .name' | sort -V | tail -n 1)

sudo ufw allow 123/udp
sudo ufw allow out to any port 123
sudo systemctl stop ntp
sudo ntpdate pool.ntp.org
sudo systemctl start ntp
sudo systemctl enable ntp
sudo ufw allow 22,80,443,53/tcp
sudo ufw allow out to any port 80
sudo ufw allow out to any port 443
sudo ufw allow out to any port 53

echo "checking if ports are available..."
check_port_443


echo "Blobber KMS has been enabled."

# TODO: replace command in docker compose file.

# TODO: there will be three states
# 1. Blobber is deployed with KMS enabled parameter and then delegate wallet gets registered to KMS and that split key is set for operational wallet for deployed blobber
# 2. User wants to set a different split key for running container, but this container should not be rented. For rented blobbers it won't work
# 3. User wants to deactivate KMS. It would require user to provide new operational wallet on UI.


* --keys_file_is_split
* --keys_file_public_key
* --keys_file_private_key
* --keys_file_client_key