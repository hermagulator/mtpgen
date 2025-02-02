#!/bin/bash

LOCK_FILE="/var/lock/fail2ban_setup.lock"

# Ensure script runs only once
if [ -f "$LOCK_FILE" ]; then
    echo "Fail2Ban setup script has already been executed. Exiting..."
    exit 1
fi

touch "$LOCK_FILE"

# Update system and install Fail2Ban
sudo apt update && sudo apt install -y fail2ban vnstat jq

# Configure Fail2Ban Filters
sudo bash -c 'cat > /etc/fail2ban/filter.d/udp_length.conf <<EOL
[Definition]
failregex = <HOST> .* UDP .* length ([1-9][0-9][0-9]|[1-9][0-9]{3,})
ignoreregex =
EOL'

sudo bash -c 'cat > /etc/fail2ban/filter.d/ack_length.conf <<EOL
[Definition]
failregex = <HOST> .* ACK .* length ([2-9][0-9][0-9]|[1-9][0-9]{3,})
ignoreregex =
EOL'

sudo bash -c 'cat > /etc/fail2ban/filter.d/high_bandwidth.conf <<EOL
[Definition]
failregex = .* SRC=<HOST> .* bytes=[5-9][0-9]{7,}
ignoreregex =
EOL'

# Configure Fail2Ban Jail
sudo bash -c 'cat > /etc/fail2ban/jail.local <<EOL
[udp_length]
enabled = true
port = all
filter = udp_length
logpath = /var/log/syslog
maxretry = 3
bantime = 3600
findtime = 60

[ack_length]
enabled = true
port = all
filter = ack_length
logpath = /var/log/syslog
maxretry = 3
bantime = 3600
findtime = 60

[high_bandwidth]
enabled = true
port = all
filter = high_bandwidth
logpath = /var/log/iptables.log
maxretry = 1
bantime = 3600
findtime = 10
EOL'

# Create Asymmetry Detection Script
sudo bash -c 'cat > /usr/local/bin/check_asymmetry.sh <<EOL
#!/bin/bash
INTERFACE=eth0
RX=\$(vnstat -i \$INTERFACE --json | jq ".interfaces[0].traffic.rx")
TX=\$(vnstat -i \$INTERFACE --json | jq ".interfaces[0].traffic.tx")
DIFF=\$(echo "\$TX - \$RX" | bc)
THRESHOLD=50000000  # 50MB

if [ \${DIFF#-} -gt \$THRESHOLD ]; then
    echo "Asymmetry detected, banning IPs..."
    sudo iptables -A INPUT -s \$(netstat -antup | grep ESTABLISHED | awk '{print \$5}' | cut -d: -f1 | sort | uniq) -j DROP
fi
EOL'

sudo chmod +x /usr/local/bin/check_asymmetry.sh

# Schedule the Asymmetry Detection Script
(sudo crontab -l 2>/dev/null; echo "* * * * * /usr/local/bin/check_asymmetry.sh") | sudo crontab -

# Restart and Enable Fail2Ban
sudo systemctl restart fail2ban
sudo systemctl enable fail2ban

# Verify Status
sudo fail2ban-client status

echo "Fail2Ban installation and configuration completed."
exit 0
