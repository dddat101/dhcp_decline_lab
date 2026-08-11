# RA_301 DHCP DECLINE Test Plan

## Objective

Validate the following behavior.

### DHCP Client

- ARP conflict detection occurs after receiving an address.
- A conflicting address is not used.
- DHCPDECLINE is transmitted.
- Address acquisition restarts after approximately 2 seconds.

### DHCP Server

- DHCPDECLINE is accepted.
- The declined address is quarantined separately.
- The address is not reused while the same DHCP server process remains running.
- Restarting the DHCP server process clears the declined-address quarantine.

---

## TC-CLIENT-01 - Normal DORA Baseline

### Procedure

Disable the duplicate host:

```bash
sudo ip netns exec ns-atk ip addr del 10.10.0.100/24 dev veth-atk
```

Trigger WAN DHCP acquisition on DUT.

### Expected

```text
DISCOVER -> OFFER -> REQUEST -> ACK
```

DUT obtains the address normally.

### Evidence

- PCAP
- DUT WAN address
- DHCP client logs

---

## TC-CLIENT-02 - ARP Conflict and DHCPDECLINE

### Setup

Restore conflict IP:

```bash
sudo ip netns exec ns-atk ip addr add 10.10.0.100/24 dev veth-atk
```

### Procedure

Trigger DHCP acquisition.

### Expected

1. Server offers/acks `10.10.0.100`.
2. DUT performs ARP conflict detection.
3. Conflict is observed.
4. DUT sends DHCPDECLINE.
5. DUT does not keep/use `10.10.0.100`.

### PASS

All five conditions are observed.

### FAIL

Any of the following:

- No ARP check.
- No DHCPDECLINE.
- DUT configures the conflicted address.
- DUT continues normal service using the duplicate address.

---

## TC-CLIENT-03 - 2-Second Reallocation

### Measurement

From PCAP:

```text
T_decline  = timestamp of DHCPDECLINE
T_discover = timestamp of next DHCPDISCOVER
delta      = T_discover - T_decline
```

Recommended QA tolerance:

```text
1.8 s <= delta <= 2.2 s
```

The tolerance is a lab recommendation, not a replacement for the product requirement.

---

## TC-SERVER-01 - Receive DHCPDECLINE

### Procedure

Use:

```bash
python3 scripts/dhcp_decline_client.py ...
```

### Expected

The DUT receives a DHCPDECLINE for the ACKed address.

Collect:

- PCAP
- DUT DHCP server log
- lease table, if available

---

## TC-SERVER-02 - Declined Address Quarantine

### Recommended DUT pool

```text
192.168.1.100 - 192.168.1.102
```

### Procedure

1. Client A acquires `.100`.
2. Client A sends DHCPDECLINE for `.100`.
3. Create clients B/C/D using different MAC addresses.
4. Exhaust `.101` and `.102`.

### Expected

`.100` must not be offered or acknowledged to any other client while the same DHCP server process remains running.

### Important

Testing only one subsequent client is insufficient. A large pool may hide address reuse.

---

## TC-SERVER-03 - Decline Lifetime

If the implementation contains `decline_time=N`, test beyond `N`.

Expected:

```text
same DHCP server process
+
time > N
=
declined address still unavailable
```

If the address becomes reusable due to timeout without process restart:

```text
NOT COMPLIANT
```

---

## TC-SERVER-04 - DHCP Process Restart

### Procedure

1. Confirm address X is declined and unavailable.
2. Record DHCP server PID.
3. Restart only the DHCP server process/service.
4. Confirm PID changed.
5. Request addresses again.

### Expected

X may become eligible again after process restart.

This is different from:

- lease expiration
- interface flap
- client restart
- WAN restart
- complete system reboot

---

## Evidence Checklist

For each run record:

```text
DUT firmware
BusyBox version
DHCP client/server binary
process PID
interface names
MAC addresses
pool
lease time
PCAP filename
test start/end time
result
```

Recommended PCAP filters:

```text
udp port 67 or udp port 68 or arp
```
