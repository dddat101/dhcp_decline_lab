#!/bin/sh

set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

need_root
load_env "${1:-./config.env}"

: "${LAN_IF:?}"
: "${NS_LAN:=ns-lan1}"

if ns_exists "$NS_LAN"; then
    if ip -n "$NS_LAN" link show "$LAN_IF" >/dev/null 2>&1; then
        ip -n "$NS_LAN" link set "$LAN_IF" down 2>/dev/null || true
        ip netns exec "$NS_LAN" ip link set "$LAN_IF" netns 1
    fi
    ip netns del "$NS_LAN" 2>/dev/null || true
fi

if ip link show "$LAN_IF" >/dev/null 2>&1; then
    ip link set "$LAN_IF" up
fi

echo "PC2 server-test topology cleaned."
