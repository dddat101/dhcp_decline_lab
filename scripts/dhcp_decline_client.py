#!/usr/bin/env python3

import argparse
import random
import sys
import time
from scapy.all import (
    Ether, IP, UDP, BOOTP, DHCP, RandMAC, sendp, sniff, conf
)

DHCP_DISCOVER = 1
DHCP_OFFER = 2
DHCP_REQUEST = 3
DHCP_DECLINE = 4
DHCP_ACK = 5


def parse_mac(text):
    parts = text.split(":")
    if len(parts) != 6:
        raise ValueError("invalid MAC")
    vals = [int(x, 16) for x in parts]
    if any(x < 0 or x > 255 for x in vals):
        raise ValueError("invalid MAC")
    if vals[0] & 0x01:
        raise ValueError("multicast MAC not allowed")
    return ":".join(f"{x:02x}" for x in vals)


def mac_bytes(mac):
    return bytes(int(x, 16) for x in mac.split(":"))


def dhcp_message_type(pkt):
    if DHCP not in pkt:
        return None
    for opt in pkt[DHCP].options:
        if isinstance(opt, tuple) and opt[0] == "message-type":
            val = opt[1]
            if isinstance(val, int):
                return val
            names = {
                "discover": DHCP_DISCOVER,
                "offer": DHCP_OFFER,
                "request": DHCP_REQUEST,
                "decline": DHCP_DECLINE,
                "ack": DHCP_ACK,
            }
            return names.get(str(val).lower())
    return None


def get_server_id(pkt):
    if DHCP not in pkt:
        return None
    for opt in pkt[DHCP].options:
        if isinstance(opt, tuple) and opt[0] == "server_id":
            return opt[1]
    return None


def send_and_wait_dhcp(iface, packet, xid, expected_type, timeout):
    def match(pkt):
        return (
            BOOTP in pkt
            and DHCP in pkt
            and pkt[BOOTP].xid == xid
            and dhcp_message_type(pkt) == expected_type
        )

    # sniff() creates its capture socket before invoking started_callback.  Send
    # only from that callback so a fast DHCP reply cannot arrive before the
    # receive socket exists.
    pkts = sniff(
        iface=iface,
        timeout=timeout,
        lfilter=match,
        count=1,
        store=True,
        started_callback=lambda: sendp(packet, iface=iface, verbose=False),
    )
    if not pkts:
        return None
    return pkts[0]


def main():
    ap = argparse.ArgumentParser(
        description="Bounded DHCP DORA client with optional DHCPDECLINE injection."
    )
    ap.add_argument("--iface", required=True)
    ap.add_argument("--server-ip", default=None,
                    help="Optional expected DHCP server IP/server-id.")
    ap.add_argument("--mac", default=None,
                    help="Client MAC. Default: random locally administered unicast MAC.")
    ap.add_argument("--timeout", type=float, default=5.0)
    ap.add_argument("--no-decline", action="store_true",
                    help="Complete DORA but do not send DHCPDECLINE.")
    args = ap.parse_args()

    if args.timeout <= 0 or args.timeout > 30:
        print("timeout must be >0 and <=30 seconds", file=sys.stderr)
        return 2

    if args.mac:
        mac = parse_mac(args.mac)
    else:
        b = [0x02, random.randrange(256), random.randrange(256),
             random.randrange(256), random.randrange(256), random.randrange(256)]
        mac = ":".join(f"{x:02x}" for x in b)

    xid = random.getrandbits(32)
    chaddr = mac_bytes(mac) + b"\x00" * 10

    conf.checkIPaddr = False

    discover = (
        Ether(src=mac, dst="ff:ff:ff:ff:ff:ff") /
        IP(src="0.0.0.0", dst="255.255.255.255") /
        UDP(sport=68, dport=67) /
        BOOTP(op=1, htype=1, hlen=6, xid=xid, flags=0x8000, chaddr=chaddr) /
        DHCP(options=[
            ("message-type", "discover"),
            ("param_req_list", [1, 3, 6, 51, 54]),
            "end",
        ])
    )

    print(f"CLIENT_MAC={mac}")
    print(f"XID=0x{xid:08x}")
    print("Sending DHCPDISCOVER")
    offer = send_and_wait_dhcp(
        args.iface, discover, xid, DHCP_OFFER, args.timeout
    )
    if offer is None:
        print("ERROR: timeout waiting for DHCPOFFER", file=sys.stderr)
        return 3

    offered_ip = offer[BOOTP].yiaddr
    server_id = get_server_id(offer) or offer[IP].src

    if args.server_ip and server_id != args.server_ip and offer[IP].src != args.server_ip:
        print(
            f"ERROR: offer from unexpected server: server_id={server_id}, ip.src={offer[IP].src}",
            file=sys.stderr,
        )
        return 4

    print(f"OFFERED_IP={offered_ip}")
    print(f"SERVER_ID={server_id}")

    request = (
        Ether(src=mac, dst="ff:ff:ff:ff:ff:ff") /
        IP(src="0.0.0.0", dst="255.255.255.255") /
        UDP(sport=68, dport=67) /
        BOOTP(op=1, htype=1, hlen=6, xid=xid, flags=0x8000, chaddr=chaddr) /
        DHCP(options=[
            ("message-type", "request"),
            ("requested_addr", offered_ip),
            ("server_id", server_id),
            ("param_req_list", [1, 3, 6, 51, 54]),
            "end",
        ])
    )

    print("Sending DHCPREQUEST")
    ack = send_and_wait_dhcp(
        args.iface, request, xid, DHCP_ACK, args.timeout
    )
    if ack is None:
        print("ERROR: timeout waiting for DHCPACK", file=sys.stderr)
        return 5

    ack_ip = ack[BOOTP].yiaddr or offered_ip
    print(f"ACKED_IP={ack_ip}")

    if args.no_decline:
        print("RESULT=DORA_OK_NO_DECLINE")
        return 0

    decline = (
        Ether(src=mac, dst="ff:ff:ff:ff:ff:ff") /
        IP(src="0.0.0.0", dst="255.255.255.255") /
        UDP(sport=68, dport=67) /
        BOOTP(op=1, htype=1, hlen=6, xid=xid, flags=0x0000, chaddr=chaddr) /
        DHCP(options=[
            ("message-type", "decline"),
            ("requested_addr", ack_ip),
            ("server_id", server_id),
            "end",
        ])
    )

    print(f"Sending DHCPDECLINE for {ack_ip}")
    sendp(decline, iface=args.iface, verbose=False)
    print(f"DECLINED_IP={ack_ip}")
    print("RESULT=DECLINE_SENT")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
