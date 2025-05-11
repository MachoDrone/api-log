#!/bin/bash
# Add Host Address at the top
echo "Host Address: $(docker logs -t nosana-node | grep 'Wallet:' | awk '{print $3}')" > api-logs.txt
echo "" >> api-logs.txt

# Add logs and diagnostics
echo "docker log snippets:" >> api-logs.txt && docker logs --timestamps --since 24h nosana-node 2>/dev/null | grep -C 21 "API proxy is offline, restarting.." >> api-logs.txt && echo "" >> api-logs.txt
echo "" >> api-logs.txt && echo "docker ps:" >> api-logs.txt && docker ps >> api-logs.txt
echo "" >> api-logs.txt && echo "docker ps -a:" >> api-logs.txt && docker ps -a >> api-logs.txt
echo "" >> api-logs.txt && echo "docker exec podman podman ps:" >> api-logs.txt && docker exec podman podman ps >> api-logs.txt
echo "" >> api-logs.txt && echo "docker exec podman podman ps -a:" >> api-logs.txt && docker exec podman podman ps -a >> api-logs.txt
echo "" >> api-logs.txt && echo "frpc-api log:" >> api-logs.txt && docker exec podman podman ps --format '{{.Names}}' | grep '^frpc-api-' | xargs -I {} docker exec podman podman logs -t {} >> api-logs.txt
echo "" >> api-logs.txt && docker logs -t nosana-node | grep 'Wallet:' | awk '{print "Host Address: " $3}' >> api-logs.txt

# WSL warning (if needed)
if grep -qi Microsoft /proc/version || grep -qi WSL /proc/version; then 
    echo -e "\033[31mTHIS SCRIPT IS MEANT FOR NATIVE UBUNTU LINUX, NOT WINDOWS WSL2.. use the correct script for your OS\033[0m" | tee -a api-logs.txt
fi

# Trim to 9.5 MB (9961472 bytes) for Discord safety
tail -c 9961472 api-logs.txt > api-logs-trimmed.txt && mv api-logs-trimmed.txt api-logs.txt

# Show final size (after trimming)
ls -ralsh api-logs.txt >> api-logs.txt

cat api-logs.txt
