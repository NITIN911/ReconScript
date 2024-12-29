#!/bin/bash

# Subdomain Enumeration Script
# Usage: ./subdomain_enum.sh example.com
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)

if [ -z "$1" ]; then
  echo "Usage: $0 <domain>"
  exit 1
fi

DOMAIN=$1
OUTPUT_FILE="subdomains_$DOMAIN.txt"

echo "${GREEN} ############################### ${RESET}"
echo "${RED} ||   Scan Smart, Scan Fast   || ${RESET}"
echo "${GREEN} ############################### ${RESET}"

echo "${RED} Starting subdomain enumeration for $DOMAIN... ${RESET}"


# Create or clear the output file
> $OUTPUT_FILE

# 1. RapidDNS
echo "${GREEN} [+] Querying RapidDNS... ${RESET}"
curl -s "https://rapiddns.io/subdomain/$DOMAIN?full=1#result" | \
  grep "<td><a" | cut -d '"' -f 2 | grep http | cut -d '/' -f3 | \
  sed 's/#results//g' | sort -u >> $OUTPUT_FILE

# 2. BufferOver DNS
echo "${GREEN} [+] Querying BufferOver DNS... ${RESET}"
curl -s "https://dns.bufferover.run/dns?q=.$DOMAIN" | \
  jq -r .FDNS_A[] | cut -d',' -f2 | sort -u >> $OUTPUT_FILE

# 3. BufferOver TLS
# echo "[*] Querying BufferOver TLS..."
# curl -s "https://tls.bufferover.run/dns?q=$DOMAIN" | \
#  jq -r .Results'[]' | rev | cut -d ',' -f1 | rev | sort -u | \
# grep "\.$DOMAIN" >> $OUTPUT_FILE

# 4. Riddler
echo "${GREEN} [+] Querying Riddler... ${RESET}"
curl -s "https://riddler.io/search/exportcsv?q=pld:$DOMAIN" | \
  grep -Po "(([\w.-]*)\.([\w]*)\.([A-z]))\w+" | sort -u >> $OUTPUT_FILE

# 5. VirusTotal
echo "${GREEN} [+] Querying VirusTotal... ${RESET}"
curl -s "https://www.virustotal.com/ui/domains/$DOMAIN/subdomains?limit=40" | \
  grep -Po "((http|https):\/\/)?(([\w.-]*)\.([\w]*)\.([A-z]))\w+" | sort -u >> $OUTPUT_FILE

# 6. Subbuster
echo "${GREEN} [+] Querying Subbuster... ${RESET}"
curl -s "https://subbuster.cyberxplore.com/api/find?domain=$DOMAIN" | \
  grep -Po "(([\w.-]*)\.([\w]*)\.([A-z]))\w+" >> $OUTPUT_FILE

# 7. CertSpotter
#echo "[*] Querying CertSpotter..."
#curl -s "https://certspotter.com/api/v1/issuances?domain=$DOMAIN&include_subdomains=true&expand=dns_names" | \
#  jq .[].dns_names | grep -Po "(([\w.-]*)\.([\w]*)\.([A-z]))\w+" | sort -u >> $OUTPUT_FILE

# 8. Web Archive
echo "${GREEN} [+] Querying Web Archive... ${RESET}"
curl -s "http://web.archive.org/cdx/search/cdx?url=*.$DOMAIN/*&output=text&fl=original&collapse=urlkey" | \
  sed -e 's_https*://__' -e "s/\/.*//" | sort -u >> $OUTPUT_FILE

# 9. Anubis
echo "${GREEN} [+] Querying Anubis... ${RESET}"
curl -s "https://jldc.me/anubis/subdomains/$DOMAIN" | \
  grep -Po "((http|https):\/\/)?(([\w.-]*)\.([\w]*)\.([A-z]))\w+" | sort -u >> $OUTPUT_FILE

# 10. SecurityTrails
echo "${GREEN} [+] Querying SecurityTrails... ${RESET}"
curl -s "https://securitytrails.com/list/apex_domain/$DOMAIN" | \
  grep -Po "((http|https):\/\/)?(([\w.-]*)\.([\w]*)\.([A-z]))\w+" | grep ".$DOMAIN" | sort -u >> $OUTPUT_FILE

# 11. Sonar
echo "${GREEN} [+] Querying Sonar...${RESET}"
curl --silent https://sonar.omnisint.io/subdomains/$DOMAIN | \
  grep -oE "[a-zA-Z0-9._-]+\\.$DOMAIN" | sort -u >> $OUTPUT_FILE

# 12. Synapsint
echo "${GREEN} [+] Querying synapsint...${RESET}"
curl --silent -X POST https://synapsint.com/report.php -d "name=https%3A%2F%2F$DOMAIN" | \
  grep -oE "[a-zA-Z0-9._-]+\\.$DOMAIN" | sort -u >> $OUTPUT_FILE

# 13. crt.sh
echo "${GREEN} [+] Querying crt.sh...${RESET}"
curl -s "https://crt.sh/?q=%25.$DOMAIN&output=json" | \
  jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u >> $OUTPUT_FILE

# Remove duplicates from the output file
sort -u $OUTPUT_FILE -o $OUTPUT_FILE

echo "${RED} {+} Subdomain enumeration completed. Results saved in $OUTPUT_FILE ${RESET}"
