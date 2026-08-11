# Troubleshooting

## PC1 dnsmasq does not start

Check:

```bash
sudo ip netns exec ns-srv ip addr
sudo ip netns exec ns-srv ss -lunp
```

Port UDP/67 may already be in use inside the namespace only if another DHCP server was started there.

## DUT does not receive OFFER

Capture:

```bash
sudo tcpdump -ni br-test-wan -e -vvv 'udp port 67 or udp port 68'
```

Check:

- DUT WAN link is up.
- `WAN_IF` is enslaved to `br-test-wan`.
- `veth-srv-br` is up.
- dnsmasq is running in `ns-srv`.
- DUT WAN DHCP client is actually active.

## DUT receives .100 but no conflict is detected

Verify `ns-atk`:

```bash
sudo ip netns exec ns-atk ip addr show dev veth-atk
sudo ip netns exec ns-atk tcpdump -ni veth-atk arp
```

Check whether the DUT emits ARP probes/requests.

If no ARP packet leaves DUT after DHCPACK, inspect BusyBox/Broadcom build options such as ARP-check support.

## dnsmasq does not offer .100 first

Set `DUT_WAN_MAC` in `config.env`.

The setup script generates a deterministic `dhcp-host` entry:

```text
MAC -> 10.10.0.100
```

## PC2 namespace script refuses the NIC

The NIC is probably used by the default route.

Use a dedicated Ethernet/USB adapter.

Only set:

```bash
FORCE=1
```

when independent management access is guaranteed.

## Scapy cannot see DHCPOFFER

Check:

```bash
sudo ip netns exec ns-lan1 tcpdump -ni "$LAN_IF" -e -vvv 'udp port 67 or udp port 68'
```

Potential causes:

- DUT DHCP server disabled.
- Wrong physical LAN port.
- VLAN/tagging required.
- LAN bridge not forwarding DHCP.
- DUT pool exhausted.
- Existing MAC binding policy.

## Field names differ in tshark

Inspect available DHCP fields:

```bash
tshark -G fields | grep -Ei 'bootp|dhcp'
```

Recent Wireshark versions may use `dhcp.*` where older versions use `bootp.*`.
