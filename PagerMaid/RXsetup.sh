#!/usr/bin/env bash

# Update package list and install necessary utilities
apt-get update && apt-get install -y apparmor apparmor-utils

# Function to check and install Docker and Docker Compose if not present
docker_check() {
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker and Docker Compose..."
        curl -fsSL https://get.docker.com | bash > /dev/null 2>&1
        apt-get install -y docker-compose > /dev/null
        echo "Docker and Docker Compose installation completed."
    else
        echo "Docker and Docker Compose are already installed."
    fi
}

# Function to start Docker container
start_docker() {
    echo "Starting Docker container..."
    docker run -dit --restart=always --name="$container_name" --hostname="$container_name" teampgm/pagermaid_pyro
    echo "Configuring parameters..."
    echo "After logging in, press Ctrl + C to allow the container to restart in the background."
    sleep 3
    docker exec -it "$container_name" bash utils/docker-config.sh || {
        echo "Failed to configure Docker container."
        return 1
    }
    echo "Restarting Docker container..."
    docker restart "$container_name"
    echo "Docker container setup completed."
}

# Function for data persistence
data_persistence() {
    echo "Starting data persistence operations..."
    data_path="/root/$container_name"
    mkdir -p "$data_path"

    if ! docker inspect "$container_name" &>/dev/null; then
        echo "Container named '$container_name' does not exist, exiting."
        return 1
    fi

    docker cp "$container_name":/pagermaid/workdir "$data_path" || {
        echo "Failed to copy data from container."
        return 1
    }
    docker stop "$container_name" &>/dev/null
    docker rm "$container_name" &>/dev/null

    # Restart the container with volume mounted
    docker run -dit -v "$data_path/workdir:/pagermaid/workdir" --restart=always --name="$container_name" --hostname="$container_name" teampgm/pagermaid_pyro

    # Check and install cron if not present
    if ! command -v crontab &> /dev/null; then
        echo "Installing cron..."
        sudo apt-get update && sudo apt-get install -y cron
        sudo systemctl enable --now cron
    fi

    # Add a cron job to restart the container hourly
    if command -v crontab &> /dev/null; then
        local cron_job="43 * * * * containers=\$(docker ps -q --filter 'name=PagerMaid'); if [ -n \"\$containers\" ]; then docker restart \$containers; fi"
        (crontab -l 2>/dev/null; echo "$cron_job") | sort - | uniq - | crontab -
        echo "Data persistence completed. Cron job added to restart containers every hour at 43 minutes past the hour."
    else
        echo "Cron installation failed; unable to add scheduled restart task."
        return 1
    fi
}

# Function to build the Docker container name
build_docker() {
    local prefix="PagerMaid-"
    container_name=""
    while [ -z "$container_name" ] || docker inspect "$container_name" &>/dev/null; do
        container_name="${prefix}$(openssl rand -hex 5)"
    done
    echo "Generated container name: $container_name"
    echo "Pulling Docker image..."
    docker pull teampgm/pagermaid_pyro || {
        echo "Failed to pull Docker image."
        return 1
    }
}

# Main function to orchestrate the installation
start_installation() {
    docker_check
    build_docker
    start_docker
    data_persistence

    # Ask user whether to reboot, default is yes
    read -p "Installation complete. Reboot now? [Y/n]: " choice
    choice=${choice:-y}  # Default to 'y' if empty

    if [[ "$choice" =~ ^[Yy]$ ]]; then
        echo "Rebooting..."
        reboot
    else
        echo "Reboot cancelled."
    fi
}


# Start the installation process directly
start_installation
