#!/bin/bash

echo "Starting system optimization script..."

# Backup existing configurations
echo "Backing up current configurations..."
cp /etc/sysctl.conf /etc/sysctl.conf.bak
cp /etc/security/limits.conf /etc/security/limits.conf.bak

# Update sysctl.conf for network optimizations
echo "Updating /etc/sysctl.conf..."
cat <<EOF >> /etc/sysctl.conf

# Network Optimizations
net.core.somaxconn = 4096
net.core.netdev_max_backlog = 65536
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_keepalive_time = 120
net.ipv4.ip_local_port_range = 1024 65535

# File Descriptors
fs.file-max = 1000000
EOF

# Apply sysctl changes
echo "Applying sysctl changes..."
sysctl -p

# Update limits.conf for file descriptor limits
echo "Updating /etc/security/limits.conf..."
cat <<EOF >> /etc/security/limits.conf
* soft nofile 1000000
* hard nofile 1000000
EOF

# Update PAM limits if necessary
echo "Ensuring PAM limits are loaded..."
if ! grep -q "pam_limits.so" /etc/pam.d/common-session; then
  echo "session required pam_limits.so" >> /etc/pam.d/common-session
fi

if ! grep -q "pam_limits.so" /etc/pam.d/common-session-noninteractive; then
  echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive
fi

# Restart services to apply changes (if necessary)
echo "Restarting necessary services..."
sysctl -w fs.file-max=1000000

# Display status
echo "System optimization complete!"
echo "Please reboot your system to ensure all changes take effect."
