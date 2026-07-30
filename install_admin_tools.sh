#!/bin/bash

# #############################################################################
## Set Colors for echo messages
# #############################################################################
red=$(tput setaf 1)
green=$(tput setaf 2)
blue=$(tput setaf 4)
magenta=$(tput setaf 5)
cyan=$(tput setaf 6)
reset=$(tput sgr0)

#Install Ansible
echo "${green}###############################################################################${reset}"
echo "${green} Installing Ansible${reset}"
echo "${green}###############################################################################${reset}"
sudo apt update
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible -y

#Install terraform
echo "${green}###############################################################################${reset}"
echo "${green} Installing Terraform${reset}"
echo "${green}###############################################################################${reset}"  
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update 
sudo apt install terraform   

#Install Packer
echo "${green}###############################################################################${reset}"
echo "${green} Installing Packer${reset}"
echo "${green}###############################################################################${reset}"  
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
sudo apt install packer

#Install kubectl
echo "${green}###############################################################################${reset}"
echo "${green} Installing Kubectl${reset}"
echo "${green}###############################################################################${reset}"  
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

#Install talosctl
echo "${green}###############################################################################${reset}"
echo "${green} Installing Talisctl${reset}"
echo "${green}###############################################################################${reset}"  
curl -Lo /tmp/talosctl https://github.com/siderolabs/talos/releases/latest/download/talosctl-linux-amd64
chmod +x /tmp/talosctl
sudo mv /tmp/talosctl /usr/local/bin/

echo "${green}###############################################################################${reset}"
echo "${green} Installation Versions Summary ${reset}"
echo "${green}###############################################################################${reset}"  

ANSIBLE_VERSION=$(ansible --version 2>/dev/null)
if [[ -n "$ANSIBLE_VERSION" ]]; then
    echo "Ansible is installed: $ANSIBLE_VERSION"
else
    echo "Ansible  is not installed"
fi

TERRAFORM_VERSION=$(terraform version 2>/dev/null | head -1)
if [[ -n "$TERRAFORM_VERSION" ]]; then
    echo "Terraform is installed: $TERRAFORM_VERSION"
else
    echo "Terraform is not installed"
fi

PACKER_VERSION=$(packer version 2>/dev/null)
if [[ -n "$PACKER_VERSION" ]]; then
    echo "Packer is installed: $PACKER_VERSION"
else
    echo "Packer is not installed"
fi

KUBECTL_VERSION=$(kubectl version --client 2>/dev/null)
if [[ -n "$KUBECTL_VERSION" ]]; then
    echo "Kubectl is installed: $KUBECTL_VERSION"
else
    echo "Kubectl is not installed"
fi

TALOSCTL_VERSION=$(talosctl version --client 2>/dev/null)
if [[ -n "$TALOSCTL_VERSION" ]]; then
    echo "Talosctl is installed: $TALOSCTL_VERSION"
else
    echo "Talosctl is not installed"
fi