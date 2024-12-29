#!/bin/bash

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)


logo(){
echo "${GREEN}

 ██████╗ ███╗   ██╗███████╗███████╗██╗  ██╗ ██████╗ ████████╗    ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗    
██╔═══██╗████╗  ██║██╔════╝██╔════╝██║  ██║██╔═══██╗╚══██╔══╝    ██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║    
██║   ██║██╔██╗ ██║█████╗  ███████╗███████║██║   ██║   ██║       ██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║    
██║   ██║██║╚██╗██║██╔══╝  ╚════██║██╔══██║██║   ██║   ██║       ██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║    
╚██████╔╝██║ ╚████║███████╗███████║██║  ██║╚██████╔╝   ██║       ██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║    
 ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝    ╚═╝       ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝    

${RESET}"
}
logo
echo "${BLUE}         This Script Help to Collect the ton of Information !!          ${RESET}"
echo "${BLUE}                      Modify as Required !!                          ${RESET}"
echo ""
echo ""
echo ""



# set vars
id="$1"
ppath="$(pwd)"
scope_path="$ppath/scope/$id"

timestamp=$(date +%s)
scan_path="$ppath/scans/$id-$timestamp"

# exit if scope path doesnt exist
if [ ! -d "$scope_path" ]; then
    echo "Path doesn't exist"
    exit 1
fi

mkdir -p "$scan_path"
cd "$scan_path"

### PERFORM SCAN ###

echo "${GREEN}[+] Starting scan against:$(cat "$scope_path/targets.txt") ${RESET}" 
cp "$scope_path/targets.txt" "$scan_path/targets.txt"

## DNS Enumeration - Find Subdomains

echo "${BLUE}[*] Running Haktrails..... ${RESET}"
cat "$scan_path/targets.txt" | haktrails subdomains | anew subs.txt | wc -l

echo "${BLUE}[*] Running Subfinder..... ${RESET}"
cat "$scan_path/targets.txt" | subfinder | anew subs.txt | wc -l

echo "${BLUE}[*] Running AMASS..... ${RESET}"
amass enum -brute -active -tr 8.8.8.8,1.1.1.1 -df "$scan_path/targets.txt" -dns-qps 100 | grep -oP '^[a-zA-Z0-9.-]+(?=\s+\(FQDN\))' | anew subs.txt | wc -l

echo "${BLUE}[*] Running Puredns..... ${RESET}"
puredns bruteforce "$ppath/lists/dnslist-small.txt" -d "$scan_path/targets.txt" --resolvers $ppath/lists/resolvers.txt | anew subs.txt | wc -l

## DNS Resolution - Resolve Discovered Subdomains

puredns resolve "$scan_path/subs.txt" -r "$ppath/lists/resolvers.txt" -w "$scan_path/resolved.txt" | wc -l
dnsx -l "$scan_path/resolved.txt" -json -o "$scan_path/dns.json" | jq -r '.a?[]?' | anew "$scan_path/ips.txt" | wc -l

## Port Scanning & HTTP Server Discovery

nmap -T4 -vv -iL "$scan_path/ips.txt" --top-ports 3000 -n --open -oX "$scan_path/nmap.xml"
tew -x "$scan_path/nmap.xml" -dnsx "$scan_path/dns.json" --vhost -o "$scan_path/hostport.txt" | httpx -sr -srd "$scan_path/response" -json -o "$scan_path/http.json"
cat "$scan_path/http.json" | jq -r '.url' | sed -e 's/:80$//g' -e 's/:443$//g' | sort -u > "$scan_path/http.txt"

## Crawling

gospider -S "$scan_path/http.txt" --json | grep "{" | jq -r '.output?' | tee "$scan_path/crawl.txt"

## JavaScript Pulling

cat "$scan_path/crawl.txt" | grep "\\.js" | httpx -sr -srd js

################### ADD SCAN LOGIC HERE ###################

# calculate time diff
end_time=$(date +%s)
seconds=$((end_time - timestamp))
time=""

if [ "$seconds" -gt 59 ]; then
    minutes=$((seconds / 60))
    time="$minutes minutes"
else
    time="$seconds seconds"
fi

echo "Scan $id took $time"
# echo "Scan $id took $time" | notify
