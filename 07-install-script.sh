#!/bin/bash
set -euo pipefail

# Script will background itself and write logs to LOG_DIR
LOG_DIR="/var/log/install-script"
MAIN_LOG="$LOG_DIR/install-script.log"

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
timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

install_pkg() {
    local pkg=$1
    local pkg_log=$2
    echo "$(timestamp) - Installing $pkg..." >>"$pkg_log"
    if dnf install -y "$pkg" >>"$pkg_log" 2>&1; then
        return 0
    else
        return 1
    fi
}

# ensure running as root
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "Please run this script as root or using sudo"
    exit 1
fi

# ensure dnf exists
if ! has_cmd dnf; then
    echo "dnf not found on this system. Exiting."
    exit 1
fi

# prepare logs
mkdir -p "$LOG_DIR"
chmod 750 "$LOG_DIR"
: >"$MAIN_LOG"
chmod 640 "$MAIN_LOG"

# if not already backgrounded, re-exec in background
if [ "${1:-}" != "--background" ]; then
    echo "$(timestamp) - Starting in background. Logs: $MAIN_LOG"
    nohup bash "$0" --background >>"$MAIN_LOG" 2>&1 &
    echo "Background PID: $!"
    exit 0
fi

echo "$(timestamp) - Background run started (PID $$)" >>"$MAIN_LOG"

# process packages
for pkg in "${PACKAGES[@]}"; do
    pkg_log="$LOG_DIR/${pkg}.log"
    : >"$pkg_log"
    chmod 640 "$pkg_log"
    echo "$(timestamp) - ----- Processing package: $pkg -----" | tee -a "$MAIN_LOG" "$pkg_log"

    if pkg_installed "$pkg"; then
        echo "$(timestamp) - $pkg is already installed (rpm query passed)" | tee -a "$MAIN_LOG" "$pkg_log"
        continue
    fi

    start_ts=$(date +%s)
    start_human=$(timestamp)
    echo "$start_human - Begin install of $pkg" >>"$MAIN_LOG"

    if install_pkg "$pkg" "$pkg_log"; then
        end_ts=$(date +%s)
        dur=$((end_ts - start_ts))
        echo "$(timestamp) - $pkg installed successfully (duration: ${dur}s)" | tee -a "$MAIN_LOG" "$pkg_log"
    else
        end_ts=$(date +%s)
        dur=$((end_ts - start_ts))
        echo "$(timestamp) - FAILED to install $pkg (duration: ${dur}s). See $pkg_log for details" | tee -a "$MAIN_LOG" "$pkg_log"
        # keep running other packages or exit? choose to continue but record failure
        continue
    fi

    # if package has an associated service, enable/start it and log result
    svc="${SERVICE_MAP[$pkg]:-}"
    if [ -n "$svc" ]; then
        echo "$(timestamp) - Handling service $svc" >>"$pkg_log"
        if systemctl list-unit-files | grep -q "^${svc}\.service" || systemctl status "$svc" >/dev/null 2>&1; then
            if systemctl enable --now "$svc" >>"$pkg_log" 2>&1; then
                echo "$(timestamp) - Service $svc enabled and started" | tee -a "$MAIN_LOG" "$pkg_log"
            else
                echo "$(timestamp) - Failed to enable/start service $svc (see $pkg_log)" | tee -a "$MAIN_LOG" "$pkg_log"
            fi
        else
            echo "$(timestamp) - Service $svc not found; please enable/start it manually if required" | tee -a "$MAIN_LOG" "$pkg_log"
        fi
    fi
done

echo "$(timestamp) - All requested packages processed." >>"$MAIN_LOG"
echo "Logs stored in $LOG_DIR (main: $MAIN_LOG)"
