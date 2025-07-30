#!/usr/bin/env bash

# PagerMaid Docker Setup Script - Optimized Version
# Enhanced with better error handling, logging, and performance improvements

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Global variables
SCRIPT_NAME="$(basename "$0")"
LOG_FILE="/tmp/${SCRIPT_NAME%.*}.log"
DOCKER_IMAGE="teampgm/pagermaid_pyro"
CONTAINER_PREFIX="PagerMaid-"
DATA_BASE_PATH="/root"
CRON_RESTART_INTERVAL="*/10"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Enhanced output functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"; }

# Cleanup function for graceful exit
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Script failed with exit code $exit_code. Check log: $LOG_FILE"
    fi
    exit $exit_code
}

# Set trap for cleanup
trap cleanup EXIT

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root. Use: sudo $0"
        exit 1
    fi
}

# System requirements check
check_system_requirements() {
    log_info "Checking system requirements..."
    
    # Check available disk space (minimum 2GB)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 2097152 ]; then  # 2GB in KB
        log_error "Insufficient disk space. At least 2GB required."
        return 1
    fi
    
    # Check memory (minimum 512MB)
    local available_memory=$(free -m | awk 'NR==2{print $7}')
    if [ "$available_memory" -lt 512 ]; then
        log_warning "Low memory detected. Performance may be affected."
    fi
    
    log_success "System requirements check passed"
}

# Optimized package installation with retry logic
install_system_packages() {
    log_info "Updating package list and installing system utilities..."
    
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if apt-get update && apt-get install -y apparmor apparmor-utils curl openssl cron; then
            log_success "System packages installed successfully"
            return 0
        else
            retry_count=$((retry_count + 1))
            log_warning "Package installation failed. Retry $retry_count/$max_retries"
            sleep 5
        fi
    done
    
    log_error "Failed to install system packages after $max_retries attempts"
    return 1
}

# Enhanced Docker installation with version check
docker_check() {
    log_info "Checking Docker installation..."
    
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        log_info "Docker is already installed (version: $docker_version)"
        
        # Check if Docker daemon is running
        if ! docker info &> /dev/null; then
            log_info "Starting Docker daemon..."
            systemctl start docker || {
                log_error "Failed to start Docker daemon"
                return 1
            }
        fi
    else
        log_info "Installing Docker and Docker Compose..."
        
        # Install Docker with error handling
        if ! curl -fsSL https://get.docker.com | bash; then
            log_error "Failed to install Docker"
            return 1
        fi
        
        # Install Docker Compose
        if ! apt-get install -y docker-compose; then
            log_error "Failed to install Docker Compose"
            return 1
        fi
        
        # Enable and start Docker service
        systemctl enable docker
        systemctl start docker
        
        log_success "Docker and Docker Compose installation completed"
    fi
    
    # Add current user to docker group if not root
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        usermod -aG docker "$SUDO_USER"
        log_info "Added $SUDO_USER to docker group"
    elif [ -n "${USER:-}" ] && [ "$USER" != "root" ]; then
        usermod -aG docker "$USER"
        log_info "Added $USER to docker group"
    fi
}

# Generate unique container name with collision avoidance
generate_container_name() {
    log_info "Generating unique container name..."
    
    local max_attempts=10
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        container_name="${CONTAINER_PREFIX}$(openssl rand -hex 4)"
        
        if ! docker inspect "$container_name" &>/dev/null; then
            log_success "Generated container name: $container_name"
            return 0
        fi
        
        attempt=$((attempt + 1))
        log_warning "Container name collision, retrying... ($attempt/$max_attempts)"
    done
    
    log_error "Failed to generate unique container name after $max_attempts attempts"
    return 1
}

# Enhanced Docker image management
pull_docker_image() {
    log_info "Pulling Docker image: $DOCKER_IMAGE"
    
    # Check if image already exists and is recent
    if docker image inspect "$DOCKER_IMAGE" &>/dev/null; then
        local image_age=$(docker image inspect "$DOCKER_IMAGE" --format '{{.Created}}' | xargs date -d)
        local current_time=$(date)
        local age_diff=$(( ($(date -d "$current_time" +%s) - $(date -d "$image_age" +%s)) / 86400 ))
        
        if [ $age_diff -lt 7 ]; then
            log_info "Recent image found (${age_diff} days old), skipping pull"
            return 0
        fi
    fi
    
    # Pull with retry logic
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if docker pull "$DOCKER_IMAGE"; then
            log_success "Docker image pulled successfully"
            return 0
        else
            retry_count=$((retry_count + 1))
            log_warning "Image pull failed. Retry $retry_count/$max_retries"
            sleep 10
        fi
    done
    
    log_error "Failed to pull Docker image after $max_retries attempts"
    return 1
}

# Optimized container startup with health checks
start_docker() {
    log_info "Starting Docker container: $container_name"
    
    # Create container with optimized settings
    if ! docker run -dit \
        --restart=unless-stopped \
        --name="$container_name" \
        --hostname="$container_name" \
        --memory="512m" \
        --memory-swap="1g" \
        --cpus="1.0" \
        "$DOCKER_IMAGE"; then
        log_error "Failed to create Docker container"
        return 1
    fi
    
    # Wait for container to be ready
    log_info "Waiting for container to be ready..."
    local timeout=30
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if docker exec "$container_name" test -f /pagermaid/utils/docker-config.sh 2>/dev/null; then
            break
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    if [ $elapsed -ge $timeout ]; then
        log_error "Container failed to become ready within $timeout seconds"
        return 1
    fi
    
    log_info "Configuring container parameters..."
    log_warning "After configuration, press Ctrl + C to continue with background setup"
    
    # Configure container with timeout
    if ! timeout 300 docker exec -it "$container_name" bash utils/docker-config.sh; then
        log_error "Container configuration failed or timed out"
        return 1
    fi
    
    log_info "Restarting container to apply configuration..."
    if ! docker restart "$container_name"; then
        log_error "Failed to restart container"
        return 1
    fi
    
    log_success "Docker container setup completed successfully"
}

# Enhanced data persistence with backup
data_persistence() {
    log_info "Setting up data persistence..."
    
    local data_path="$DATA_BASE_PATH/$container_name"
    
    # Create data directory with proper permissions
    if ! mkdir -p "$data_path"; then
        log_error "Failed to create data directory: $data_path"
        return 1
    fi
    
    # Verify container exists
    if ! docker inspect "$container_name" &>/dev/null; then
        log_error "Container '$container_name' does not exist"
        return 1
    fi
    
    # Copy data with verification
    log_info "Copying container data to persistent storage..."
    if ! docker cp "$container_name":/pagermaid/workdir "$data_path/"; then
        log_error "Failed to copy data from container"
        return 1
    fi
    
    # Verify data was copied successfully
    if [ ! -d "$data_path/workdir" ]; then
        log_error "Data copy verification failed"
        return 1
    fi
    
    # Gracefully stop and remove old container
    log_info "Stopping and removing temporary container..."
    docker stop "$container_name" &>/dev/null || true
    docker rm "$container_name" &>/dev/null || true
    
    # Create new container with persistent volume
    log_info "Creating container with persistent data volume..."
    if ! docker run -dit \
        -v "$data_path/workdir:/pagermaid/workdir" \
        --restart=unless-stopped \
        --name="$container_name" \
        --hostname="$container_name" \
        --memory="512m" \
        --memory-swap="1g" \
        --cpus="1.0" \
        "$DOCKER_IMAGE"; then
        log_error "Failed to create persistent container"
        return 1
    fi
    
    # Setup automated restart cron job
    setup_cron_restart
    
    log_success "Data persistence setup completed"
}

# Optimized cron job setup
setup_cron_restart() {
    log_info "Setting up automated container restart..."
    
    # Ensure cron is installed and running
    if ! command -v crontab &> /dev/null; then
        log_info "Installing cron service..."
        if ! apt-get install -y cron; then
            log_error "Failed to install cron"
            return 1
        fi
    fi
    
    # Enable and start cron service
    systemctl enable cron &>/dev/null || true
    systemctl start cron &>/dev/null || true
    
    # Create optimized cron job
    local cron_job="$CRON_RESTART_INTERVAL * * * * /usr/bin/docker ps -q --filter 'name=$CONTAINER_PREFIX' | /usr/bin/xargs -r /usr/bin/docker restart >/dev/null 2>&1"
    
    # Add cron job with duplicate prevention
    (crontab -l 2>/dev/null | grep -v "$CONTAINER_PREFIX" || true; echo "$cron_job") | crontab -
    
    log_success "Automated restart scheduled every 10 minutes for PagerMaid containers"
}

# Main installation orchestrator with error recovery
start_installation() {
    log_info "Starting PagerMaid Docker installation..."
    log_info "Log file: $LOG_FILE"
    
    # Pre-installation checks
    check_root
    check_system_requirements
    
    # Installation steps with error handling
    install_system_packages || return 1
    docker_check || return 1
    generate_container_name || return 1
    pull_docker_image || return 1
    start_docker || return 1
    data_persistence || return 1
    
    log_success "PagerMaid installation completed successfully!"
    log_info "Container name: $container_name"
    log_info "Data path: $DATA_BASE_PATH/$container_name/workdir"
    log_info "Use 'docker logs $container_name' to view container logs"
    log_info "Use 'docker exec -it $container_name bash' to access container shell"
}

# Script entry point
main() {
    # Initialize logging
    echo "PagerMaid Docker Setup - $(date)" > "$LOG_FILE"
    
    # Run installation
    start_installation
}

# Execute main function
main "$@"
