#!/bin/bash

# Check if Mosh is installed
if ! command -v mosh &> /dev/null; then
    echo "Mosh is not installed. Installing..."
    sudo apt-get update
    sudo apt-get install -y mosh
fi

# Get the public IP address of the current host
current_ip=$(curl -s ifconfig.me)

# Connect to Mosh using root username and the detected IP
mosh root@$current_ip