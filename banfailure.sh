#!/bin/bash

# Ensure you are running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "You need to run this script as root."
    exit 1
fi

# Install Fail2Ban if not installed
echo "Installing Fail2Ban..."
apt update && apt install -y fail2ban

# Create necessary filter files for UDP, ACK/SYN, and high data transfer
echo "Creating filter for UDP high rate and length..."
cat > /etc/fail2ban/filter.d/udp_high_rate_length.conf <<EOL
[Definition]
failregex = .*UDP.*length (\d+).*rate (\d+)
ignoreregex =
EOL

echo "Creating filter for TCP ACK/SYN high rate and length..."
cat > /etc/fail2ban/filter.d/tcp_ack_syn.conf <<EOL
[Definition]
failregex = .*SYN.*ACK.*length (\d+).*rate (\d+)
ignoreregex =
EOL

echo "Creating filter for high data transfer (over 50MB/s)..."
cat > /etc/fail2ban/filter.d/high_data_transfer.conf <<EOL
[Definition]
failregex = .*DROP.*(.*).*length (\d+).*rate (\d+)
ignoreregex =
EOL

# Configure custom jails for each filter in jail.local
echo "Configuring jails in /etc/fail2ban/jail.local..."

cat >> /etc/fail2ban/jail.local <<EOL

[udp-high-rate-length]
enabled  = true
filter   = udp_high_rate_length
action   = iptables[name=UDPHighRateLength, port=all, protocol=udp]
logpath  = /var/log/syslog
maxretry = 1
bantime  = 3600
findtime = 600

[tcp-ack-syn]
enabled  = true
filter   = tcp_ack_syn
action   = iptables[name=TCPAckSyn, port=all, protocol=tcp]
logpath  = /var/log/syslog
maxretry = 1
bantime  = 3600
findtime = 600

[high-data-transfer]
enabled  = true
filter   = high_data_transfer
action   = iptables[name=HighDataTransfer, port=all, protocol=all]
logpath  = /var/log/syslog
maxretry = 1
bantime  = 3600
findtime = 600
EOL

# Configure iptables for high data transfer logging
echo "Configuring iptables for high data transfer logging..."
iptables -A INPUT -m limit --limit 1/s -j LOG --log-prefix "IPT high data transfer: "

# Whitelist Telegram IP ranges (from https://core.telegram.org/resources/cidr.txt)
echo "Whitelisting Telegram IP ranges..."
cidr_url="https://core.telegram.org/resources/cidr.txt"
cidr_file="/tmp/telegram_cidr.txt"

# Download the Telegram CIDR file
curl -s $cidr_url -o $cidr_file

# Loop through each CIDR block and add it to iptables whitelist
while read -r cidr; do
    # Skip empty lines and comments
    if [[ ! -z "$cidr" && ! "$cidr" =~ ^# ]]; then
        iptables -A INPUT -s "$cidr" -j ACCEPT
        echo "Whitelisted $cidr"
    fi
done < $cidr_file

# Restart Fail2Ban to apply the changes
echo "Restarting Fail2Ban..."
systemctl restart fail2ban

# Check Fail2Ban status
echo "Checking Fail2Ban status..."
fail2ban-client status

echo "Script execution completed!"
