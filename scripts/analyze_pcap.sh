#!/bin/sh

set -eu

PCAP="${1:-}"
[ -n "$PCAP" ] || {
    echo "Usage: $0 <capture.pcap>" >&2
    exit 2
}
[ -f "$PCAP" ] || {
    echo "File not found: $PCAP" >&2
    exit 2
}

command -v tshark >/dev/null 2>&1 || {
    echo "Missing tshark" >&2
    exit 2
}

echo "=== DHCP / ARP timeline ==="

# Prefer modern dhcp fields, fall back to verbose summary if unavailable.
if tshark -G fields 2>/dev/null | grep -q 'dhcp.option.dhcp'; then
    tshark -r "$PCAP" \
      -Y 'dhcp || arp' \
      -T fields \
      -e frame.time_relative \
      -e eth.src \
      -e eth.dst \
      -e ip.src \
      -e ip.dst \
      -e dhcp.option.dhcp \
      -e dhcp.ip.your \
      -e dhcp.option.requested_ip_address \
      -e arp.opcode \
      -e arp.src.proto_ipv4 \
      -e arp.dst.proto_ipv4
else
    tshark -r "$PCAP" -Y 'bootp || arp'
fi

echo
echo "=== DHCPDECLINE frames ==="

if tshark -G fields 2>/dev/null | grep -q 'dhcp.option.dhcp'; then
    tshark -r "$PCAP" -Y 'dhcp.option.dhcp == 4'
else
    tshark -r "$PCAP" -Y 'bootp.option.dhcp == 4'
fi
