#!/bin/sh

set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

need_root
load_env "${1:-./config.env}"
need_cmd ip

: "${LAN_IF:?}"
: "${NS_LAN:=ns-lan1}"

ip link show "$LAN_IF" >/dev/null 2>&1 || die "LAN_IF not found in root namespace: $LAN_IF"
protect_management_if "$LAN_IF"

if ns_exists "$NS_LAN"; then
    die "Namespace already exists: $NS_LAN"
fi

ip link set "$LAN_IF" down
ip netns add "$NS_LAN"
ip link set "$LAN_IF" netns "$NS_LAN"
ip -n "$NS_LAN" link set lo up
ip -n "$NS_LAN" link set "$LAN_IF" up

echo "PC2 server-test namespace ready."
echo "Namespace: $NS_LAN"
echo "Interface: $LAN_IF"
