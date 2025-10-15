#!/bin/bash

# 1. Check for sudo/root privileges
if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: This script requires sudo/root privileges."
  exit 1
fi
echo "✅ Sudo access confirmed."

# 2. Detect OS type
if [ -f /etc/debian_version ]; then
  OS="debian"
elif [ -f /etc/redhat-release ] || [ -f /etc/system-release ]; then
  OS="rhel"
else
  echo "❌ Unsupported OS. Only Debian/Ubuntu or RHEL/Amazon Linux are supported."
  exit 1
fi

# 3. Update system and install MySQL
if [ "$OS" = "debian" ]; then
  echo "🔄 Detected Debian/Ubuntu system."
  echo "🔄 Running apt update..."
  apt update -y && apt install -y mysql-server

  echo "🔍 Verifying MySQL installation..."
  if dpkg -l | grep -q mysql-server; then
    echo "✅ MySQL installed successfully via APT."
  else
    echo "❌ Error: MySQL installation failed on Debian/Ubuntu."
    exit 1
  fi

elif [ "$OS" = "rhel" ]; then
  echo "🔄 Detected Amazon Linux / RHEL / CentOS system."
  if command -v dnf >/dev/null 2>&1; then
    echo "📦 Installing MySQL via DNF..."
    dnf install -y mysql-server
  else
    echo "📦 Installing MySQL via YUM..."
    yum install -y mysql-server
  fi

  echo "🔍 Enabling and starting MySQL service..."
  systemctl enable mysqld
  systemctl start mysqld

  echo "🔍 Verifying MySQL installation..."
  if systemctl status mysqld >/dev/null 2>&1; then
    echo "✅ MySQL is installed and running on Amazon Linux/RHEL."
  else
    echo "❌ Error: MySQL service failed to start."
    exit 1
  fi
fi

echo "🎉 MySQL installation completed successfully!"
