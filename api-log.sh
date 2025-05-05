#!/bin/bash

# Check dependencies (excluding podman, as it may be nested or native)
for cmd in docker grep awk mktemp; do
    if ! command -v $cmd >/dev/null; then
        echo "Error: $cmd is required but not installed. Please install it."
        exit 1
    fi
done

# Check Docker permissions
if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker permission denied. Ensure user is in docker group or has sudo access."
    exit 1
fi

# Check nosana-node container
if ! docker ps -q -f name=^nosana-node$ >/dev/null; then
    echo "Error: nosana-node Docker container not found. Ensure it is running."
    exit 1
fi

# Check Podman availability (nested or native)
if ! docker ps -q -f name=^podman$ >/dev/null && ! command -v podman >/dev/null; then
    echo "Error: Neither podman Docker container nor native podman found."
    exit 1
fi

# Check write permissions
if ! touch api-log.txt 2>/dev/null; then
    echo "Error: Cannot write to api-log.txt in current directory. Check permissions."
    exit 1
fi
rm -f api-log.txt

# Handle colors
if [ "${NO_COLOR:-0}" = "1" ] || [ "$(tput colors 2>/dev/null || echo 0)" -lt 8 ]; then
    BLUE=""
    RESET=""
else
    BLUE="\033[34m"
    RESET="\033[0m"
fi

# Ensure temporary file cleanup
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

# Main logic
(docker ps -q -f name=^nosana-node$ >/dev/null && { docker logs --timestamps --since 24h nosana-node 2>/dev/null | grep -C 21 "API proxy is offline, restarting.." > "$tmp"; if [ -s "$tmp" ]; then (echo "" && echo "Docker logs for nosana-node:" && cat "$tmp" && echo "" && if docker ps -q -f name=^podman$ >/dev/null; then echo "" && echo "Podman ps -a:" && docker exec podman podman ps -a 2>/dev/null || echo "Failed to run podman ps -a" && echo "" && echo "Podman ps:" && docker exec podman podman ps 2>/dev/null || echo "Failed to run podman ps" && echo "" && echo "Logs for frpc-api containers:" && docker exec podman sh -c 'for container in $(podman ps --format "{{.Names}}" | grep "frpc-api-" || echo ""); do [ -n "$container" ] && { echo "Logs for $container:"; podman logs -t "$container" 2>/dev/null; } || echo "No frpc-api containers found"; done' 2>/dev/null || echo "Failed to get frpc-api logs"; else echo "" && echo "WSL2 Podman ps -a:" && podman ps -a 2>/dev/null || echo "Failed to run WSL2 podman ps -a" && echo "" && echo "WSL2 Podman ps:" && podman ps 2>/dev/null || echo "Failed to run WSL2 podman ps" && echo "" && echo "WSL2 Logs for frpc-api containers:" && for container in $(podman ps --format "{{.Names}}" | grep "frpc-api-" || echo ""); do [ -n "$container" ] && { echo "Logs for $container:"; podman logs -t "$container" 2>/dev/null; } || echo "No frpc-api containers found"; done 2>/dev/null || echo "Failed to get WSL2 frpc-api logs"; fi && echo "" && echo "Host Address: $(docker logs -t nosana-node 2>/dev/null | grep "Wallet:" | awk -F' ' '{if (NF >= 3) print $3; else print "Wallet not found"}' || echo "No wallet logs found")") > api-log.txt || echo "Error writing to api-log.txt" && cat api-log.txt && ls -tralsh api-log.txt; else echo -e "${BLUE}Docker logs for nosana-node:${RESET}" && echo -e "${BLUE}No API proxy offline logs found${RESET}"; fi; } || { echo -e "${BLUE}Docker logs for nosana-node:${RESET}" && echo -e "${BLUE}No API proxy offline logs found${RESET}"; })
