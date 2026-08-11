#!/bin/sh

set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

need_root
load_env "${1:-./config.env}"

for c in ip dnsmasq awk grep; do need_cmd "$c"; done

: "${WAN_IF:?}"
: "${WAN_BR:=br-test-wan}"
: "${NS_SRV:=ns-srv}"
: "${NS_ATK:=ns-atk}"
: "${WAN_SERVER_IP:=10.10.0.1}"
: "${WAN_PREFIX:=24}"
: "${WAN_CONFLICT_IP:=10.10.0.100}"
: "${WAN_POOL_START:=10.10.0.100}"
: "${WAN_POOL_END:=10.10.0.110}"
: "${WAN_LEASE:=10m}"

ip link show "$WAN_IF" >/dev/null 2>&1 || die "WAN_IF not found: $WAN_IF"
protect_management_if "$WAN_IF"

if ns_exists "$NS_SRV" || ns_exists "$NS_ATK" || link_exists "$WAN_BR"; then
    die "Existing test objects detected. Run pc1_cleanup_client_test.sh first."
fi

ip link add "$WAN_BR" type bridge
ip link set "$WAN_BR" up
ip link set "$WAN_IF" master "$WAN_BR"
ip link set "$WAN_IF" up

ip netns add "$NS_SRV"
ip link add veth-srv type veth peer name veth-srv-br
ip link set veth-srv netns "$NS_SRV"
ip link set veth-srv-br master "$WAN_BR"
ip link set veth-srv-br up
ip -n "$NS_SRV" link set lo up
ip -n "$NS_SRV" link set veth-srv up
ip -n "$NS_SRV" addr add "$WAN_SERVER_IP/$WAN_PREFIX" dev veth-srv

ip netns add "$NS_ATK"
ip link add veth-atk type veth peer name veth-atk-br
ip link set veth-atk netns "$NS_ATK"
ip link set veth-atk-br master "$WAN_BR"
ip link set veth-atk-br up
ip -n "$NS_ATK" link set lo up
ip -n "$NS_ATK" link set veth-atk up
ip -n "$NS_ATK" addr add "$WAN_CONFLICT_IP/$WAN_PREFIX" dev veth-atk

RUN_DIR="/tmp/ra301-dhcp-decline"
mkdir -p "$RUN_DIR"

DNSMASQ_CONF="$RUN_DIR/dnsmasq.conf"
DNSMASQ_PID="$RUN_DIR/dnsmasq.pid"
DNSMASQ_LOG="$RUN_DIR/dnsmasq.log"

cat >"$DNSMASQ_CONF" <<EOF
port=0
interface=veth-srv
bind-interfaces
dhcp-range=$WAN_POOL_START,$WAN_POOL_END,$WAN_LEASE
dhcp-option=3,$WAN_SERVER_IP
dhcp-option=6,$WAN_SERVER_IP
dhcp-authoritative
log-dhcp
log-facility=$DNSMASQ_LOG
pid-file=$DNSMASQ_PID
EOF

if [ -n "${DUT_WAN_MAC:-}" ]; then
    echo "dhcp-host=$DUT_WAN_MAC,$WAN_CONFLICT_IP" >>"$DNSMASQ_CONF"
fi

ip netns exec "$NS_SRV" dnsmasq --conf-file="$DNSMASQ_CONF"

echo "PC1 client-test topology ready."
echo "Bridge: $WAN_BR"
echo "DHCP server: $WAN_SERVER_IP"
echo "Conflict IP: $WAN_CONFLICT_IP"
echo "dnsmasq log: $DNSMASQ_LOG"
