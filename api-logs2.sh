#!/bin/bash
# ---------- Command Template Script ----------

# Ensure we have a terminal for the prompt
if [ ! -e /dev/tty ]; then
  echo "ERROR: No terminal available for prompt. Please run this in a real terminal."
  exit 1
fi

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

# Sanitize username for filename (remove spaces, slashes, etc.)
discord_user_sanitized=$(echo "$discord_user" | tr -c 'A-Za-z0-9_-' '_')
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
logfile="${timestamp}_${discord_user_sanitized}.log"

# Capture all host addresses once, stripping ANSI color codes
mapfile -t host_addrs < <(
  docker logs -t nosana-node | grep 'Wallet:' | awk '{print $3}' | \
  sed -r 's/\x1B\[[0-9;]*[mK]//g'
)

# ---------- START OF COMMANDS TO PLACE IN LOG ----------
REQUIRE_API_OFFLINE=1  # Set to 1 to require API offline event, 0 to skip docker logs if not found

# Search for API offline events
api_event_logs=$(docker logs --timestamps --since 24h nosana-node 2>&1 | grep -E -C 21 "API proxy is offline, restarting..|Node API is detected offline" | grep -v "Error response from daemon: No such container:" | grep -v "command not found")

if [ -z "$api_event_logs" ]; then
  if [ "${REQUIRE_API_OFFLINE:-0}" -eq 1 ]; then
    echo "No 'API proxy is offline, restarting..' or 'Node API is detected offline' events found in the last 24 hours."
    echo "No API offline events found. Script will exit and not upload logs."
    exit 0
  else
    SKIP_DOCKER_LOGS=1
  fi
else
  SKIP_DOCKER_LOGS=0
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
  if [ "$SKIP_DOCKER_LOGS" -eq 0 ]; then
    echo "$api_event_logs"
  else
    echo "No 'API proxy is offline, restarting..' or 'Node API is detected offline' events found in the last 24 hours."
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

# Prepend filename and size to the top of the log file (human-readable)
filesize=$(ls -lh "$logfile" | awk '{print $5}')
tmpfile=$(mktemp)
echo "File: $logfile  Size: $filesize" > "$tmpfile"
cat "$logfile" >> "$tmpfile"
mv "$tmpfile" "$logfile"

# --- Auto-upload log ---
seg1=$(curl -s https://raw.githubusercontent.com/MachoDrone/aut-up/refs/heads/main/up7 | tr -d '\r\n')
seg2=$(curl -s https://raw.githubusercontent.com/MachoDrone/aut-up/refs/heads/main/up-a8 | tr -d '\r\n')
seg3=$(curl -s https://raw.githubusercontent.com/MachoDrone/aut-up/refs/heads/main/up16 | tr -d '\r\n')
seg4=$(curl -s https://raw.githubusercontent.com/MachoDrone/aut-up/refs/heads/main/up27 | tr -d '\r\n')
seg5=$(curl -s https://raw.githubusercontent.com/MachoDrone/aut-up/refs/heads/main/up1 | tr -d '\r\n')
label1=$(curl -s https://raw.githubusercontent.com/MachoDrone/aut-up/refs/heads/main/z-dwn | tr -d '\r\n')
label2=$(curl -s https://raw.githubusercontent.com/MachoDrone/aut-up/refs/heads/main/uq-s | tr -d '\r\n')

upload_string="${seg1}${seg2}${seg3}${seg4}${seg5}"
upload_label="${label1}${label2}"

# Prepare JSON payload in a temp file
python3 -c "
import json,sys
with open('$logfile', 'r', encoding='utf-8', errors='replace') as f:
    content = f.read()
with open('payload.json', 'w', encoding='utf-8') as out:
    json.dump({'public':True,'files':{'$logfile':{'content':content}}}, out)
"

response=$(curl -s -X POST -H "${upload_label} ${upload_string}" -d @payload.json https://api.github.com/gists)
rm -f payload.json

gist_url=$(echo "$response" | grep '"html_url"' | head -1 | cut -d '"' -f4)
if [ -n "$gist_url" ]; then
  gist_id=$(basename "$gist_url")
  echo
  echo "uploaded $gist_id"
else
  echo
  echo "upload failed."
fi

rm -f "$logfile"
