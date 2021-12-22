#!/bin/bash

set -e
set -o pipefail

# Update the system first
sudo apt update
sudo apt upgrade -y

# Install prerequisites
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker’s stable repository
# Note: If you want to add `nightly` or `test` repository, add the words
# `nightly` or `test` (or both) after the word `stable` in the commands below.
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update the `apt` package index
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Create necessary groups if needed
getent group docker || sudo groupadd docker
sudo usermod -aG docker ubuntu

# This should not be needed, but just to be sure, let’s start Docker on boot
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
