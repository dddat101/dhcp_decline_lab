#!/bin/sh

set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

need_root
load_env "${1:-./config.env}"
need_cmd tcpdump

: "${LAN_IF:?}"
: "${NS_LAN:=ns-lan1}"
: "${RESULTS_DIR:=./results}"

ns_exists "$NS_LAN" || die "Namespace not found: $NS_LAN"

STAMP=$(date +%Y%m%d_%H%M%S)
OUT="$RESULTS_DIR/server_test_$STAMP"
mkdir -p "$OUT"

echo "Capturing $NS_LAN/$LAN_IF"
echo "Output: $OUT/capture.pcap"
echo "Stop with Ctrl-C."

exec ip netns exec "$NS_LAN" \
    tcpdump -i "$LAN_IF" -nn -e -s 0 \
    -w "$OUT/capture.pcap" \
    '(udp port 67 or udp port 68) or arp'
