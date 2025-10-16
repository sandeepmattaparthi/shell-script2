#!/bin/bash
set -euo pipefail

# vars - adjust package names as needed for your distribution
PACKAGES=(nginx nodejs docker jenkins java-11-openjdk gcc gcc-c++ python3 git make)

# map packages to service names to enable/start after install (if applicable)
declare -A SERVICE_MAP=(
    [nginx]=nginx
    [docker]=docker
    [jenkins]=jenkins
)

# helpers
has_cmd() { command -v "$1" >/dev/null 2>&1; }
pkg_installed() { rpm -q "$1" >/dev/null 2>&1; }
install_pkg() {
    local pkg=$1
    echo "Installing $pkg..."
    dnf install -y "$pkg"
}

# prechecks
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "Please run this script as root or using sudo"
    exit 1
fi

if ! has_cmd dnf; then
    echo "dnf not found on this system. Exiting."
    exit 1
fi

# install packages in a loop
for pkg in "${PACKAGES[@]}"; do
    if pkg_installed "$pkg"; then
        echo "$pkg is already installed (rpm query passed)"
        continue
    fi

    # try installing
    if install_pkg "$pkg"; then
        echo "$pkg installed successfully"
    else
        echo "Failed to install $pkg"
        exit 1
    fi

    # if package has an associated service, enable/start it
    svc="${SERVICE_MAP[$pkg]:-}"
    if [ -n "$svc" ]; then
        if systemctl list-unit-files | grep -q "^${svc}\.service" || systemctl status "$svc" >/dev/null 2>&1; then
            systemctl enable --now "$svc"
            echo "Service $svc enabled and started"
        else
            echo "Service $svc not found; please enable/start it manually if required"
        fi
    fi
done

echo "All requested packages processed."
