#!/bin/bash

if [[ $DEBUG = "1" ]]; then
    set -x
fi

set -e
set -o pipefail

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <instance-name>"
    exit 1
fi

NAME=$1
HYPERVISOR="hyperkit"

if [[ $2 = "--virtualbox" ]]; then
    HYPERVISOR="virtualbox"
fi

# Configure Multipass to use the correct hypervisor
CURRENT=$(sudo multipass get local.driver)
if [[ $HYPERVISOR = "virtualbox" ]]; then
    if [[ ! $CURRENT = "virtualbox" ]]; then
        sudo multipass set local.driver=virtualbox
        sleep 2
        echo "==> Configured Multipass to use VirtualBox; exiting, please re-run the script with the same parameters again!"
        exit 0
    else
        echo "--> Multipass is already configured to use VirtualBox, continuing…"
    fi
else
    if [[ ! $CURRENT = "hyperkit" ]]; then
        sudo multipass set local.driver=hyperkit
        sleep 2
        echo "==> Configured Multipass to use HyperKit; exiting, please re-run the script with the same parameters again!"
        exit 0
    else
        echo "--> Multipass is already configured to use HyperKit, continuing…"
    fi
fi

# Spawn a new instance with a name given as first argument to the script
# If needed, can specify `focal` or other Ubuntu codename as last argument
# By default, Multipass will spawn a new instance with the latest stable Ubuntu,
# which is `focal` at the time of the script creation
echo "==> Creating a new VM, this might take a while…"
multipass launch --name "$NAME"

# Transfer setup script to the new instance
echo "==> Installing Docker inside the VM…"
multipass transfer setup-instance.sh "$NAME":/home/ubuntu/setup-instance.sh

# Execute script
multipass exec "$NAME" -- /bin/bash -x "/home/ubuntu/setup-instance.sh"

# Enable passwordless SSH to the Multipass instance
# First, let’s create a new SSH key pair
if [ -f ~/.ssh/id_multipass_docker ]; then
    echo "--> SSH key already exists, skipping and reusing ~/.ssh/id_multipass_docker…"
else
    echo "==> Creating SSH key pair…"
    ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_multipass_docker -N ""
fi

# Add the key to list of authorized keys
echo "==> Setting up passwordless SSH…"
multipass transfer ~/.ssh/id_multipass_docker.pub "$NAME":/home/ubuntu/.ssh/id_multipass_docker.pub
multipass exec "$NAME" -- /bin/bash -c "cat /home/ubuntu/.ssh/id_multipass_docker.pub >> /home/ubuntu/.ssh/authorized_keys"

# Find out IP address & connection method to the instance
IP_ADDRESS=$(multipass info docker | grep IPv4 | awk '{ print $2; }')
PORT=22

if [[ $HYPERVISOR = "virtualbox" ]]; then
    IP_ADDRESS="localhost"
    PORT=$(sudo VBoxManage showvminfo docker | grep -i nic | grep "name = ssh," | sed -rn 's/.*host port = ([[:digit:]]+).*/\1/p')
fi

echo "--> VM detected at ${IP_ADDRESS}:${PORT}…"

# Alter ~/.ssh/config
if grep "Host multipass" ~/.ssh/config > /dev/null; then
    echo "--> Host multipass exists in SSH config, skipping ~/.ssh/config modification…"
    # TODO: this is actually not 100% correct, we should replace the existing entry with new one as SSH port might have changed in case of VirtualBox hypervisor
else
    echo "==> Modifying ~/.ssh/config…"
    {
        echo
        echo "Host multipass"
        echo "  HostName $IP_ADDRESS"
        echo "  Port $PORT"
        echo "  User ubuntu"
        echo "  IdentityFile ~/.ssh/id_multipass_docker"
     } >> ~/.ssh/config
fi

if docker context ls | grep multipass > /dev/null; then
    echo "--> Docker context multipass exists, skipping creation…"
else
    echo "==> Creating Docker context…"
    docker context create multipass --docker "host=ssh://multipass"
fi

docker context use multipass

echo "=> You should be good to go! Try running \`docker container run hello-world\` now!"
