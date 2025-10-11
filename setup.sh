#!/bin/bash

set -e

echo "Installing AWS CLI, Terraform, and Containerlab..."

# Update and install dependencies
sudo apt-get update -y
sudo apt-get install -y curl wget unzip gnupg software-properties-common

# Install AWS CLI v2
echo "Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install --update 2>/dev/null || sudo ./aws/install
# rm -rf aws awscliv2.zip

# Install Terraform
echo "Installing Terraform..."
wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update -y
sudo apt-get install -y terraform

# # Install Docker
# echo "Installing Docker..."
# curl -fsSL https://get.docker.com | sudo sh

# # Configure Docker permissions
# sudo usermod -aG docker $USER
# newgrp docker
# sudo systemctl restart docker.services
# wait

# Install Containerlab
echo "Installing Containerlab..."
curl -sL https://containerlab.dev/setup | sudo -E bash -s "all"

# Restart Docker
sudo systemctl restart docker.service

echo ""
echo "Installation complete!"
echo "Note: Log out and back in for Docker group changes to take effect."
