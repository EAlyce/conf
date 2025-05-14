#!/usr/bin/env bash
set -euo pipefail

# Optimized Snell Docker Installer Script

# --- Configuration --- 
# Consider changing the NODE_BASE_DIR if /root/snelldocker is not desired.
NODE_BASE_DIR="/root/snelldocker"
# Consider using a specific version for the Docker image instead of :latest for stability.
SNELL_IMAGE="azurelane/snell:latest"
PRIMARY_DNS="8.8.8.8"
SECONDARY_DNS="8.8.4.4"
FALLBACK_DNS_1="9.9.9.12"
FALLBACK_DNS_2="208.67.220.220"
FALLBACK_DNS_3="94.140.14.141"

# --- Colors --- 
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Logging --- 
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# --- Error Handling --- 
trap 'log_error "An error occurred at line $LINENO. Exiting..."; exit 1' ERR

# --- Helper Functions ---

check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_error "You must be root to run this script"
        exit 1
    fi
}

install_tools() {
    log_info "Installing required tools..."
    # Using -qq for quiet, but errors should still propagate due to set -e
    # Consider logging apt output to a file for debugging if issues arise.
    if DEBIAN_FRONTEND=noninteractive apt-get update -qq && \
       DEBIAN_FRONTEND=noninteractive apt-get install -qq -y curl wget git iptables netcat openssl; then
        log_info "Tools installation completed."
    else
        log_warn "Tool installation might have encountered issues. Please check apt logs."
        # Even with set -e, apt-get might return 0 on some partial failures with -y.
        # A more robust check might involve verifying each tool with 'command -v'.
    fi
}

install_docker_and_compose() {
    if ! command -v docker &>/dev/null; then
        log_info "Installing Docker..."
        if curl -fsSL https://get.docker.com | bash &>/dev/null; then
            log_info "Docker installed."
        else
            log_error "Docker installation failed."
            exit 1
        fi
    else
        log_info "Docker is already installed."
    fi

    if ! command -v docker-compose &>/dev/null; then
        log_info "Installing Docker Compose..."
        # Ensure apt database is updated before trying to install docker-compose
        # This might be redundant if install_tools was just run, but good for standalone use.
        DEBIAN_FRONTEND=noninteractive apt-get update -qq
        if DEBIAN_FRONTEND=noninteractive apt-get install -qq -y docker-compose; then
            log_info "Docker Compose installed."
        else
            log_error "Docker Compose installation failed."
            exit 1
        fi
    else
        log_info "Docker Compose is already installed."
    fi
    
    # Enable and start Docker if not already running (idempotent)
    if ! systemctl is-active --quiet docker; then
        log_info "Starting and enabling Docker service..."
        systemctl enable docker &>/dev/null
        systemctl start docker &>/dev/null
    fi
    log_info "Docker and Docker Compose setup verified."
}

# Returns public IP and location as "ip|location" or just "ip" if location fails
get_public_ip_and_location() {
    local ip_services=("ipinfo.io" "ifconfig.me" "icanhazip.com" "ident.me")
    local public_ip=""
    local location="N/A"

    for service_host in "${ip_services[@]}"; do
        log_info "Attempting to get public IP from $service_host..."
        case "$service_host" in 
            "ipinfo.io")
                # ipinfo.io can provide both IP and city in one go
                local response
                response=$(curl -s --connect-timeout 5 "ipinfo.io/json")
                if [[ -n "$response" ]]; then
                    public_ip=$(echo "$response" | grep -oP '"ip": "\K[^"].*?(?=")')
                    location=$(echo "$response" | grep -oP '"city": "\K[^"].*?(?=")')
                    if [[ -z "$location" ]]; then location="N/A"; fi # Ensure location is N/A if not found
                fi
                ;;
            *)
                public_ip=$(curl -s --connect-timeout 5 "$service_host")
                ;;
        esac

        if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            log_info "Public IP: $public_ip"
            if [[ "$service_host" != "ipinfo.io" && "$location" == "N/A" ]]; then # If IP from other service, try location from ipinfo
                log_info "Attempting to get location from ipinfo.io..."
                local loc_temp
                loc_temp=$(curl -s --connect-timeout 5 "ipinfo.io/$public_ip/city")
                if [[ -n "$loc_temp" && "$loc_temp" != *"Rate limit exceeded"* && "$loc_temp" != *"Wrong ip"* ]]; then 
                    location="$loc_temp"
                fi
            fi
            log_info "Host location: $location"
            echo "$public_ip|$location"
            return 0
        fi
        public_ip="" # Reset for next attempt
    done
    
    log_error "Unable to obtain public IP after trying multiple services."
    exit 1
}

# Helper to add line to file if not exists
ensure_line_in_file() {
    local line="$1"
    local file="$2"
    grep -qxF -- "$line" "$file" || echo "$line" >> "$file"
}

setup_environment() {
    log_info "Setting up environment..."
    
    # Locale (assuming en_US.UTF-8 is desired and available)
    # These commands might require user interaction or pre-seeding on some systems.
    # For a fully non-interactive script, ensure locales are pre-generated or handle errors.
    if ! locale -a | grep -iq "en_US.utf8"; then 
        log_info "Generating en_US.UTF-8 locale..."
        locale-gen en_US.UTF-8 &>/dev/null
    fi
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 &>/dev/null
    
    log_info "Configuring DNS..."
    # Overwrite resolv.conf. This might be reverted by network managers.
    # A more robust solution involves configuring the network manager (e.g., systemd-resolved, netplan, NetworkManager).
    echo -e "nameserver $PRIMARY_DNS\nnameserver $SECONDARY_DNS" > /etc/resolv.conf
    
    log_info "Applying system optimizations (sysctl)..."
    ensure_line_in_file "net.ipv4.tcp_fastopen = 0" /etc/sysctl.conf
    ensure_line_in_file "net.core.default_qdisc = fq" /etc/sysctl.conf
    ensure_line_in_file "net.ipv4.tcp_congestion_control = bbr" /etc/sysctl.conf
    ensure_line_in_file "net.ipv4.tcp_ecn = 1" /etc/sysctl.conf
    ensure_line_in_file "vm.swappiness = 0" /etc/sysctl.conf
    sysctl -p &>/dev/null
    
    log_info "Setting up basic firewall rules for UDP range (60000-61000)..."
    # Check if rule exists before adding
    if ! iptables -C INPUT -p udp --dport 60000:61000 -j ACCEPT &>/dev/null; then
        iptables -A INPUT -p udp --dport 60000:61000 -j ACCEPT
    fi
    
    log_info "Configuring MTU for non-loopback interfaces to 1500..."
    # This is a generic setting; specific environments might need different MTUs.
    for iface in $(ls /sys/class/net); do
        if [ "$iface" != "lo" ]; then
            log_info "Setting MTU for $iface to 1500."
            ip link set dev "$iface" mtu 1500 || log_warn "Failed to set MTU for $iface. It might be down or virtual."
        fi
    done
    
    log_info "Environment setup completed."
}

# Returns an available port
generate_port() {
    local attempts=0
    local max_attempts=20 # Increased attempts
    local port
    
    log_info "Searching for an available port..."
    while [ $attempts -lt $max_attempts ]; do
        port=$(shuf -i 5000-30000 -n 1)
        if ! nc -z 127.0.0.1 "$port" &>/dev/null; then # Check TCP
            if ! ss -tulnp | grep -q ":$port " ; then # More robust check for TCP/UDP
                 log_info "Selected port: $port"
                 echo "$port"
                 return 0
            fi
        fi
        ((attempts++))
    done
    
    log_error "Failed to find an available port after $max_attempts attempts."
    exit 1
}

# Argument: $1 = port
setup_firewall_for_service() {
    local port="$1"
    log_info "Configuring firewall for service on port $port..."
    if ! iptables -C INPUT -p tcp --dport "$port" -j ACCEPT &>/dev/null; then
        iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
        log_info "Firewall rule added for TCP port $port."
    else
        log_info "Firewall rule for TCP port $port already exists."
    fi
}

# Returns a generated password
generate_password() {
    local pass
    pass=$(openssl rand -base64 32) || {
        log_error "Failed to generate password."
        exit 1
    }
    log_info "Password generated successfully."
    echo "$pass"
}

# Arguments: $1 = port, $2 = password
setup_docker_service() {
    local port="$1"
    local password="$2"
    local node_dir="$NODE_BASE_DIR/Snell$port"
    
    local platform
    case "$(uname -m)" in
        x86_64)  platform="linux/amd64" ;;
        aarch64) platform="linux/arm64" ;;
        armv7l)  platform="linux/arm/v7" ;;
        i386)    platform="linux/386" ;;
        *)       log_error "Unsupported architecture: $(uname -m)"; exit 1 ;;
    esac
    
    log_info "Setting up Docker configuration in $node_dir for platform $platform..."
    
    mkdir -p "$node_dir/snell-conf" "$node_dir/data" || {
        log_error "Failed to create directories in $node_dir."
        exit 1
    }
    
    create_docker_compose "$node_dir" "$platform" "$port" "$password"
    create_snell_config "$node_dir" "$port" "$password"
    
    log_info "Starting Docker container Snell$port..."
    # Using docker-compose for consistency, though 'docker compose' is the newer syntax.
    # Ensure docker-compose command is used if that's what was installed.
    if ! docker-compose -f "$node_dir/docker-compose.yml" up -d; then
        log_error "Failed to start Docker container Snell$port. Check logs: docker logs Snell$port"
        # Attempt to show logs on failure
        docker-compose -f "$node_dir/docker-compose.yml" logs --tail=50
        exit 1
    fi
    
    log_info "Docker setup for Snell$port completed."
    log_info "To view logs, run: docker logs Snell$port"
}

# Arguments: $1 = node_dir, $2 = platform, $3 = port, $4 = password
create_docker_compose() {
    local node_dir="$1"
    local platform="$2"
    local port="$3"
    local password="$4"
    
    log_info "Creating docker-compose.yml in $node_dir..."
    # Note: network_mode: host and privileged: true grant extensive permissions to the container.
    # Evaluate if these are strictly necessary for snell and if more granular permissions can be used.
    cat > "$node_dir/docker-compose.yml" <<EOF
version: '3.8' # Specify compose file version
services:
  snell:
    image: $SNELL_IMAGE
    container_name: Snell$port
    restart: always
    network_mode: host # Warning: High privileges
    privileged: true   # Warning: High privileges
    platform: $platform
    environment:
      - PORT=$port
      - PSK=$password
      - IPV6=false # Consider making this configurable
      - DNS=$PRIMARY_DNS,$SECONDARY_DNS # Using configured DNS
    volumes:
      - ./snell-conf:/etc/snell # Use relative path from compose file location
      - ./data:/var/lib/snell   # Use relative path
EOF
}

# Arguments: $1 = node_dir, $2 = port, $3 = password
create_snell_config() {
    local node_dir="$1"
    local port="$2"
    local password="$3"

    log_info "Creating snell.conf in $node_dir/snell-conf..."
    cat > "$node_dir/snell-conf/snell.conf" <<EOF
[snell-server]
listen = 0.0.0.0:$port
psk = $password
tfo = false # tcp_fastopen is disabled in sysctl by this script
obfs = off # Consider making this configurable
dns = $PRIMARY_DNS,$SECONDARY_DNS,$FALLBACK_DNS_1,$FALLBACK_DNS_2,$FALLBACK_DNS_3 # Using configured DNS
ipv6 = false # Matches Docker compose env
EOF
}

# Arguments: $1 = public_ip, $2 = location, $3 = port, $4 = password
print_node_info() {
    local public_ip="$1"
    local location="$2"
    local port="$3"
    local password="$4"

    echo
    log_info "Configuration Summary:"
    echo "-------------------------"
    echo "Snell Server Details:"
    echo "  Location:    $location"
    echo "  Public IP:   $public_ip"
    echo "  Port:        $port"
    echo "  Password:    $password"
    echo "  Snell Config: snell, $public_ip, $port, psk=$password, version=4" # Assuming version 4 is current
    echo "-------------------------"
    echo
}

# --- Main Function --- 
main() {
    log_info "Starting Snell Docker installation script..."
    
    check_root
    install_tools
    install_docker_and_compose
    
    local ip_loc_data
    ip_loc_data=$(get_public_ip_and_location)
    local public_ip=$(echo "$ip_loc_data" | cut -d'|' -f1)
    local location=$(echo "$ip_loc_data" | cut -d'|' -f2)

    setup_environment # General environment setup
    
    local service_port
    service_port=$(generate_port)
    
    setup_firewall_for_service "$service_port"
    
    local service_password
    service_password=$(generate_password)
    
    setup_docker_service "$service_port" "$service_password"
    
    print_node_info "$public_ip" "$location" "$service_port" "$service_password"
    
    log_info "Installation completed successfully!"
}

# --- Script Execution --- 
main
