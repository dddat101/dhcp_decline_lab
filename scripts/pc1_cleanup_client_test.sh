#!/bin/sh

set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

need_root
load_env "${1:-./config.env}"

: "${WAN_IF:?}"
: "${WAN_BR:=br-test-wan}"
: "${NS_SRV:=ns-srv}"
: "${NS_ATK:=ns-atk}"

RUN_DIR="/tmp/ra301-dhcp-decline"
PID_FILE="$RUN_DIR/dnsmasq.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE" 2>/dev/null || true)
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        kill "$PID" || true
    fi
fi

if ns_exists "$NS_SRV"; then ip netns del "$NS_SRV"; fi
if ns_exists "$NS_ATK"; then ip netns del "$NS_ATK"; fi

if ip link show "$WAN_IF" >/dev/null 2>&1; then
    ip link set "$WAN_IF" nomaster 2>/dev/null || true
    ip link set "$WAN_IF" up 2>/dev/null || true
fi

if link_exists "$WAN_BR"; then
    ip link del "$WAN_BR"
fi

rm -rf "$RUN_DIR"

echo "PC1 client-test topology cleaned."
