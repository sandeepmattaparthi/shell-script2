#!/bin/bash

set -euo pipefail

# vars
DB_PKGS=(mysql-server mariadb-server)
DB_SERVICES=(mysqld mariadb)
OTHER_PKGS=(git)

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

# install DB (or detect existing)
if pkg_installed mysql-server || pkg_installed mariadb-server || has_cmd mysql; then
    echo "MySQL/MariaDB is already installed"
else
    INSTALLED_DB_PKG=""
    for p in "${DB_PKGS[@]}"; do
        if install_pkg "$p"; then
            INSTALLED_DB_PKG="$p"
            break
        fi
    done

    if [ -z "${INSTALLED_DB_PKG}" ]; then
        echo "Neither mysql-server nor mariadb-server could be installed"
        exit 1
    fi

    # determine service name
    DB_SERVICE=""
    for s in "${DB_SERVICES[@]}"; do
        if systemctl list-unit-files | grep -q "^${s}\.service" || systemctl status "${s}" >/dev/null 2>&1; then
            DB_SERVICE="$s"
            break
        fi
    done

    if [ -n "${DB_SERVICE}" ]; then
        systemctl enable --now "${DB_SERVICE}"
        echo "${DB_SERVICE} enabled and started"
    else
        echo "Could not determine DB service name. Please enable/start the database service manually."
    fi
fi

# install other packages
for p in "${OTHER_PKGS[@]}"; do
    if pkg_installed "$p" || has_cmd "$p"; then
        echo "$p is already installed"
    else
        if install_pkg "$p"; then
            echo "$p installed successfully"
        else
            echo "$p installation failed"
            exit 1
        fi
    fi
done
