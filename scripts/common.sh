#!/bin/sh

set -eu

die()
{
    echo "ERROR: $*" >&2
    exit 1
}

need_root()
{
    [ "$(id -u)" -eq 0 ] || die "Run as root."
}

need_cmd()
{
    command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

load_env()
{
    ENV_FILE="${1:-./config.env}"
    [ -f "$ENV_FILE" ] || die "Config file not found: $ENV_FILE"
    # shellcheck disable=SC1090
    . "$ENV_FILE"
}

default_route_if()
{
    ip route show default 2>/dev/null | awk 'NR==1 {for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}'
}

protect_management_if()
{
    IFACE="$1"
    FORCE_VAL="${FORCE:-0}"
    DEF_IF="$(default_route_if || true)"

    if [ "$FORCE_VAL" != "1" ] && [ -n "$DEF_IF" ] && [ "$DEF_IF" = "$IFACE" ]; then
        die "$IFACE carries the current default route. Use a dedicated adapter or set FORCE=1 with independent management."
    fi
}

ns_exists()
{
    ip netns list | awk '{print $1}' | grep -qx "$1"
}

link_exists()
{
    ip link show "$1" >/dev/null 2>&1
}
