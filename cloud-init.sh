#!/bin/bash
curl -sL bit.ly/get-ops | bash
source ~/.bashrc
ops -t
IP="$(ip -4 -o addr | awk  '$2 ~ /en/ {print $4}' | cut -d/ -f1)"
APIHOST="http://$IP.nip.io"
echo "-------"
echo "APIHOST=$APIHOST"
