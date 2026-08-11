#!/bin/sh

set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

need_root
load_env "${1:-./config.env}"
need_cmd tcpdump

: "${WAN_BR:=br-test-wan}"
: "${RESULTS_DIR:=./results}"

link_exists "$WAN_BR" || die "Bridge not found: $WAN_BR"

STAMP=$(date +%Y%m%d_%H%M%S)
OUT="$RESULTS_DIR/client_test_$STAMP"
mkdir -p "$OUT"

echo "Capturing on $WAN_BR"
echo "Output: $OUT/capture.pcap"
echo "Stop with Ctrl-C."

exec tcpdump -i "$WAN_BR" -nn -e -s 0 \
    -w "$OUT/capture.pcap" \
    '(udp port 67 or udp port 68) or arp'
