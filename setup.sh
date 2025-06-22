#!/bin/bash

# Exit on any error
set -e

# Function to display messages
echo_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

# Function to validate port number
validate_port() {
    local port=$1
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# Update and upgrade system packages
echo_info "Updating and upgrading system packages..."
apt update -y
apt upgrade -y
apt dist-upgrade -y
apt autoremove -y
apt autoclean -y

# Prompt for Minecraft port
while true; do
    read -p "Enter the port for Minecraft (default is 25565): " minecraft_port
    # If empty, use default 25565
    minecraft_port=${minecraft_port:-25565}
    if validate_port "$minecraft_port"; then
        echo_info "Using Minecraft port: $minecraft_port"
        break
    else
        echo "Please enter a valid port number (1-65535)."
    fi
done

# Write custom iptables rules to a temporary file
echo_info "Writing custom iptables rules to a temporary file..."
cat << EOF > custom_iptables.txt
*raw
:PREROUTING ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
COMMIT
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
COMMIT
*mangle
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -m conntrack --ctstate INVALID -j DROP
-A PREROUTING -p tcp -m tcp ! --tcp-flags FIN,SYN,RST,ACK SYN -m conntrack --ctstate NEW -j DROP
-A PREROUTING -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP
-A PREROUTING -p tcp -m tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
-A PREROUTING -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j DROP
-A PREROUTING -p tcp -m tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
-A PREROUTING -p tcp -m tcp --tcp-flags FIN,RST FIN,RST -j DROP
-A PREROUTING -p tcp -m tcp --tcp-flags FIN,ACK FIN -j DROP
-A PREROUTING -p tcp -m tcp --tcp-flags ACK,URG URG -j DROP
-A PREROUTING -p tcp -m tcp --tcp-flags FIN,ACK FIN -j DROP
-A PREROUTING -p tcp -m tcp --tcp-flags PSH,ACK PSH -j DROP
-A PREROUTING -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG FIN,SYN,RST,PSH,ACK,URG -j DROP
-A PREROUTING -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP
-A PREROUTING -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG FIN,PSH,URG -j DROP
-A PREROUTING -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG FIN,SYN,PSH,URG -j DROP
-A PREROUTING -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG FIN,SYN,RST,ACK,URG -j DROP
-A PREROUTING -f -j DROP
COMMIT
*filter
:INPUT DROP [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -d 127.0.0.0/8 ! -i lo -j REJECT --reject-with icmp-port-unreachable
-A INPUT -p tcp -m tcp --dport $minecraft_port -j ACCEPT
-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
-A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
-A OUTPUT -j ACCEPT
-A FORWARD -j REJECT --reject-with icmp-port-unreachable
-A INPUT -j DROP
COMMIT
EOF

# Apply custom iptables rules
echo_info "Applying custom iptables rules..."
iptables-restore < custom_iptables.txt

# Install iptables-persistent
echo_info "Installing iptables-persistent..."
apt install -y iptables-persistent

# Ensure iptables-persistent service is enabled
systemctl enable netfilter-persistent

# Prompt for Java 21 installation
while true; do
    read -p "Do you want to install Java 21? (y/n): " java_choice
    case $java_choice in
        [Yy]* )
            echo_info "Installing Java 21..."
            apt install -y openjdk-21-jdk
            echo_info "Java 21 installed. Version:"
            java -version
            break
            ;;
        [Nn]* )
            echo_info "Skipping Java 21 installation."
            break
            ;;
        * )
            echo "Please answer y or n."
            ;;
    esac
done

echo_info "VPS setup completed successfully!"
