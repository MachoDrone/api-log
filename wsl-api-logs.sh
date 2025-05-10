#!/bin/bash
echo "" > api-logs.txt && echo "docker log snippets:" >> api-logs.txt && docker logs --timestamps --since 24h nosana-node 2>/dev/null | grep -C 21 "API proxy is offline, restarting.." >> api-logs.txt && echo "" >> api-logs.txt
echo "" >> api-logs.txt && echo "docker ps:" >> api-logs.txt && docker ps >> api-logs.txt
echo "" >> api-logs.txt && echo "docker ps -a:" >> api-logs.txt && docker ps -a >> api-logs.txt
echo "" >> api-logs.txt && echo "podman ps:" >> api-logs.txt && podman ps >> api-logs.txt
echo "" >> api-logs.txt && echo "podman ps -a:" >> api-logs.txt && podman ps -a >> api-logs.txt
echo "" >> api-logs.txt && echo "frpc-api log:" >> api-logs.txt && podman ps -a --format '{{.Names}}' | grep '^frpc-api-' | xargs -I {} podman logs -t {} >> api-logs.txt
echo "" >> api-logs.txt && docker logs -t nosana-node | grep 'Wallet:' | awk '{print "Host Address: " $3}' >> api-logs.txt
ls -ralsh api-logs.txt >> api-logs.txt
if ! grep -qi Microsoft /proc/version && ! grep -qi WSL /proc/version; then echo -e "\033[31mTHIS SCRIPT IS MEANT FOR WINDOWS WSL2, NOT NATIVE UBUNTU LINUX\033[0m" | tee -a api-logs.txt; fi
cat api-logs.txt
