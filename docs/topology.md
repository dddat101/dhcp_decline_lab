# Physical and Logical Topology

## Test A - DUT DHCP Client

### Physical Cabling

```text
Ubuntu PC1                            DUT
+------------------+               +------------------+
| USB/Ethernet NIC |---------------| WAN              |
|                  |               | DHCP Client      |
+------------------+               +------------------+
```

### Logical Topology

```text
                    Ubuntu PC1

                        br-test-wan
                     /      |       \
                    /       |        \
              DUT WAN   veth-srv   veth-atk
                          |           |
                       ns-srv      ns-atk
                          |           |
                    10.10.0.1    10.10.0.100
                    DHCP server   duplicate host
```

Packet path:

```text
DUT DHCPDISCOVER
  -> br-test-wan
  -> ns-srv/dnsmasq

dnsmasq DHCPOFFER/ACK
  -> br-test-wan
  -> DUT

DUT ARP check for 10.10.0.100
  -> br-test-wan
  -> ns-atk
  -> conflict response
```

## Test B - DUT DHCP Server

### Physical Cabling

```text
Ubuntu PC2                            DUT
+------------------+               +------------------+
| Ethernet NIC     |---------------| LAN              |
| ns-lan1          |               | DHCP Server      |
+------------------+               +------------------+
```

Packet path:

```text
ns-lan1
  DHCPDISCOVER
     |
     v
DUT LAN DHCP server
     |
  DHCPOFFER
     |
  DHCPREQUEST
     |
   DHCPACK
     |
DHCPDECLINE
```

## Addressing

The project intentionally avoids:

```text
192.168.0.0/24
```

on the WAN emulator side.

WAN test network:

```text
10.10.0.0/24
```

DUT LAN test network remains:

```text
192.168.1.0/24
```

because it is the DUT's product LAN network under test.
