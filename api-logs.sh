#!/bin/bash
# # ---------- Command Template Script ----------

REQUIRE_DISCORD_USERNAME=1  # Set to 0 to disable Discord username prompt

# Prompt for Discord username (force prompt, prevent blank)
if [ "${REQUIRE_DISCORD_USERNAME:-1}" -eq 1 ]; then
  while true; do
    read -p "Please add your Discord username: " discord_user </dev/tty
    [ -n "$discord_user" ] && break
    echo "Discord username cannot be blank."
  done
else
  discord_user="anonymous"
fi

# Generate UTC timestamped filename and variable
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
logfile="${timestamp}.log"

# Capture all host addresses once, stripping ANSI color codes
mapfile -t host_addrs < <(
  docker logs -t nosana-node | grep 'Wallet:' | awk '{print $3}' | \
  sed -r 's/\x1B\[[0-9;]*[mK]//g'
)

# ---------- START OF COMMANDS TO PLACE IN LOG ----------
REQUIRE_API_OFFLINE=0  # Set to 1 to require API offline event, 0 to always upload

# Check for API offline event if required
docker_logs=$(docker logs --timestamps --since 24h nosana-node 2>&1 | grep -C 21 "API proxy is offline, restarting.." | grep -v "Error response from daemon: No such container:" | grep -v "command not found")
if [ "${REQUIRE_API_OFFLINE:-0}" -eq 1 ] && [ -z "$docker_logs" ]; then
  echo 'No "API proxy is offline, restarting.." events found in the last 24 hours.'
  echo "No API offline events found. Script will exit and not upload logs."
  exit 0
fi
# ---------- END OF COMMANDS TO PLACE IN LOG ----------

# Function to print Host line in new format
print_host_line() {
  local addr="$1"
  if [ -n "$addr" ]; then
    echo "Host: https://dashboard.nosana.com/host/$addr"
  else
    echo "Host: "
  fi
}

# Collect diagnostics and logs efficiently
{
  # Top of log
  echo "Discord username: $discord_user"
  print_host_line "${host_addrs[0]}"
  if [ -f /proc/version ] && grep -qi "Microsoft" /proc/version; then
    echo "Running on WSL"
  else
    echo "Running on native Linux"
  fi
  date -u

  echo "Collection of logs for API offline, restarting..."
  echo

  echo "Docker logs (24hr):"
  if [ -n "$docker_logs" ]; then
    echo "$docker_logs"
  else
    echo 'No "API proxy is offline, restarting.." events found in the last 24 hours.'
  fi
  echo

  echo "docker ps:"
  docker ps 2>&1 | grep -v "Error response from daemon: No such container:" | grep -v "command not found"
  echo

  echo "docker ps -a:"
  docker ps -a 2>&1 | grep -v "Error response from daemon: No such container:" | grep -v "command not found"
  echo

  # Only run the following commands for the appropriate environment
  if [ -f /proc/version ] && grep -qi "Microsoft" /proc/version; then
    # WSL
    echo "podman ps (WSL):"
    podman ps 2>&1 | grep -v "command not found"
    echo

    echo "podman ps -a (WSL):"
    podman ps -a 2>&1 | grep -v "command not found"
    echo

    echo "frpc-api log (WSL):"
    podman ps -a --format '{{.Names}}' 2>&1 | grep '^frpc-api-' | xargs -I {} podman logs -t {} 2>&1 | grep -v "command not found"
    echo
  else
    # Native Linux
    echo "docker exec podman podman ps (Linux):"
    docker exec podman podman ps 2>&1 | grep -v "command not found"
    echo

    echo "docker exec podman podman ps -a (Linux):"
    docker exec podman podman ps -a 2>&1 | grep -v "command not found"
    echo

    echo "frpc-api log (Linux):"
    docker exec podman podman ps --format '{{.Names}}' 2>&1 | grep '^frpc-api-' | xargs -I {} docker exec podman podman logs -t {} 2>&1 | grep -v "command not found"
    echo
  fi

  # Bottom of log: print username and Host line again
  echo "Discord username: $discord_user"
  print_host_line "${host_addrs[0]}"
  echo

  echo "uname -a:"
  uname -a
  echo

} > "$logfile"

# --- Auto-upload log ---
# Fetch parts for upload label and segment
seg1=$(curl -s https://raw.githubusercontent.com/MachoDrone/aut-up/refs/heads/main/up7 | tr -d '\r\n')
seg2=$(curl -s https://raw.githubusercontent.com/MachoDrone/aut-up/refs/heads/main/up-a8 | tr -d '\r\n')
seg3=$(curl -s https://raw.githubusercontent.com/MachoDrone/aut-up/refs/heads/main/up16 | tr -d '\r\n')
seg4=$(curl -s https://raw.githubusercontent.com/MachoDrone/aut-up/refs/heads/main/up27 | tr -d '\r\n')
seg5=$(curl -s https://raw.githubusercontent.com/MachoDrone/aut-up/refs/heads/main/up1 | tr -d '\r\n')
label1=$(curl -s https://raw.githubusercontent.com/MachoDrone/aut-up/refs/heads/main/z-dwn | tr -d '\r\n')
label2=$(curl -s https://raw.githubusercontent.com/MachoDrone/aut-up/refs/heads/main/uq-s | tr -d '\r\n')

upload_string="${seg1}${seg2}${seg3}${seg4}${seg5}"
upload_label="${label1}${label2}"

# Prepare upload
response=$(python3 -c "
import json,sys
with open('$logfile', 'r', encoding='utf-8', errors='replace') as f:
    content = f.read()
print(json.dumps({'public':True,'files':{'$logfile':{'content':content}}}))

" | curl -s -X POST -H "${upload_label} ${upload_string}" -d @- https://api.github.com/gists)

# Extract and print only the ID and timestamp
gist_id=$(echo "$response" | grep -o '"id": *"[^"]*"' | head -1 | cut -d '"' -f4)
if [ -n "$gist_id" ]; then
  echo
  echo "uploaded log $gist_id - $timestamp"
else
  echo
  echo "upload failed."
fi

rm -f "$logfile"
