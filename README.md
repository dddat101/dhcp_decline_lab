# DHCP DECLINE Test Lab

Automation project for validating the DHCP DECLINE on a DUT gateway/AP.

## Scope

This project covers two independent compliance paths:

1. **DUT as DHCP client**
   - DUT receives DHCPACK.
   - DUT performs ARP conflict detection before using the assigned IPv4 address.
   - On conflict, DUT sends DHCPDECLINE.
   - DUT does not use the conflicted IPv4 address.
   - DUT retries address acquisition about 2 seconds after DHCPDECLINE.

2. **DUT as DHCP server**
   - DUT receives DHCPDECLINE from a LAN client.
   - The declined IPv4 address is excluded from future allocations while the DHCP server process remains running.
   - The declined IPv4 address becomes eligible again only after the DHCP server process restarts.

## Recommended Hardware

- Ubuntu PC1: WAN emulator, DHCP server, duplicate-IP host, capture.
- Ubuntu PC2: LAN DHCP client / packet injector / capture.
- DUT:
  - WAN: DHCP client under test.
  - LAN: DHCP server under test.
- Two Ethernet links are recommended:
  - PC1 <-> DUT WAN
  - PC2 <-> DUT LAN

Do not use the TP-Link upstream router for this isolated test.

## Project Layout

```text
ra301_dhcp_decline_lab_v1/
├── README.md
├── config.env.example
├── requirements.txt
├── docs/
│   ├── topology.md
│   ├── test-plan.md
│   └── troubleshooting.md
└── scripts/
    ├── common.sh
    ├── pc1_setup_client_test.sh
    ├── pc1_cleanup_client_test.sh
    ├── pc1_capture.sh
    ├── pc2_setup_server_test.sh
    ├── pc2_cleanup_server_test.sh
    ├── pc2_capture.sh
    ├── dhcp_decline_client.py
    └── analyze_pcap.sh
```

## Dependencies

Install on both Ubuntu PCs as required:

```bash
sudo apt update
sudo apt install -y iproute2 bridge-utils tcpdump tshark dnsmasq python3 python3-pip
python3 -m pip install --user -r requirements.txt
```

For Debian/Ubuntu systems that restrict system-wide pip, use a virtual environment:

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
```

## Configuration

Copy the template:

```bash
cp config.env.example config.env
```

Edit `config.env`.

Important fields:

```bash
WAN_IF=enx...
LAN_IF=enp...
DUT_WAN_MAC=aa:bb:cc:dd:ee:ff
```

The scripts intentionally refuse to operate on an interface carrying the current default route unless:

```bash
FORCE=1
```

This protects management connectivity.

## Test A - DUT DHCP Client

### 1. Cable

```text
Ubuntu PC1 ---- DUT WAN
```

### 2. Setup PC1

```bash
sudo ./scripts/pc1_setup_client_test.sh ./config.env
```

This creates:

```text
br-test-wan
├── physical DUT-WAN NIC
├── ns-srv
│   └── 10.10.0.1/24
└── ns-atk
    └── 10.10.0.100/24
```

`ns-atk` owns the first offered address so that DUT ARP conflict detection should trigger.

If `DUT_WAN_MAC` is configured, dnsmasq reserves `10.10.0.100` for that MAC to make the test deterministic.

### 3. Start capture

```bash
sudo ./scripts/pc1_capture.sh ./config.env
```

Default output:

```text
results/client_test_YYYYmmdd_HHMMSS/
```

### 4. Trigger DHCP acquisition on DUT

Use the DUT's normal WAN service manager. Avoid killing `udhcpc` directly unless the Broadcom architecture requires it.

Expected packet sequence:

```text
DISCOVER
OFFER 10.10.0.100
REQUEST
ACK 10.10.0.100
ARP conflict check
DHCPDECLINE 10.10.0.100
~2 seconds
DISCOVER
```

### 5. Analyze capture

```bash
sudo ./scripts/analyze_pcap.sh results/.../capture.pcap
```

### 6. Cleanup

```bash
sudo ./scripts/pc1_cleanup_client_test.sh ./config.env
```

## Test B - DUT DHCP Server

### 1. Cable

```text
Ubuntu PC2 ---- DUT LAN
```

Default DUT LAN assumption:

```text
192.168.1.1/24
```

### 2. Setup PC2

```bash
sudo ./scripts/pc2_setup_server_test.sh ./config.env
```

This moves the selected physical NIC into `ns-lan1`. The script refuses to move the current default-route interface unless `FORCE=1`.

### 3. Capture

```bash
sudo ./scripts/pc2_capture.sh ./config.env
```

### 4. Inject DORA + DHCPDECLINE

```bash
sudo ip netns exec ns-lan1 \
  python3 ./scripts/dhcp_decline_client.py \
    --iface "$LAN_IF" \
    --server-ip 192.168.1.1
```

The script:

1. Sends DHCPDISCOVER.
2. Receives DHCPOFFER.
3. Sends DHCPREQUEST.
4. Receives DHCPACK.
5. Sends DHCPDECLINE for the assigned address.
6. Prints the declined address for later verification.

### 5. Verify quarantine

Recommended DUT DHCP pool for this test:

```text
192.168.1.100 - 192.168.1.102
```

Use a small pool so the test can exhaust the non-declined addresses.

Repeat the Python client with different synthetic MAC addresses:

```bash
for i in 1 2 3 4; do
  sudo ip netns exec ns-lan1 \
    python3 ./scripts/dhcp_decline_client.py \
      --iface "$LAN_IF" \
      --server-ip 192.168.1.1 \
      --mac "02:00:00:00:00:0$i" \
      --no-decline
done
```

The declined IPv4 address must not be offered again while the DHCP server process is still the same process.

Then restart only the DUT DHCP server process and verify that the declined address becomes eligible again.

## Acceptance Criteria

See [docs/test-plan.md](docs/test-plan.md).

## Safety

- Tests are isolated.
- No flood traffic is generated.
- Scripts use bounded retries and timeouts.
- Scripts do not flush host firewall rules.
- Scripts do not replace the system default route.
- Management-interface protection is enabled by default.
