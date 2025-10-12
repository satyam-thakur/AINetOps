## ⚙️ **Arista cEOS Cheat Sheet**

**System**

```
show version
show running-config
copy running-config startup-config
reload
```

**Interfaces**

```
show interfaces status
show ip interface brief
show vlan
show mac address-table
```

**Routing**

```
show ip route
show ip arp
show ip ospf neighbor
show ip bgp summary
```

**Config Mode**

```
configure terminal
interface Ethernet1
ip address 10.0.0.1/24
no shutdown
exit
```

**Diagnostics**

```
ping <IP>
traceroute <IP>
show logging
```

---

## 🧩 **Nokia SR Linux Cheat Sheet**

**System**

```
info system version
show system cpu
show system memory
show system alarms
```

**Config**

```
enter candidate
set system name <hostname>
set interface ethernet-1/1 admin-state enable
commit now
exit
```

**Interfaces / IP**

```
info from state interface all
show interfaces brief
set interface ethernet-1/1 subinterface 1 ipv4 address 10.0.0.2/24
```

**Routing / ARP**

```
info from state network-instance default route-table ipv4-unicast
show network-instance default arp
```

**Diagnostics**

```
ping network-instance default <IP>
traceroute network-instance default <IP>
```

**Containerlab**

```
docker exec -it <node> sr_cli
sudo clab inspect --name <lab>
```

---

Would you like me to format this as a downloadable **PDF or Markdown cheat sheet** (for quick reference in your lab)?

Here’s a quick **Arista cEOS general command cheat sheet** (useful for automation and manual ops):

---

### 🔹 Basic System Commands

```bash
show version               # OS, kernel, and uptime info
show hostname              # Display device hostname
show running-config        # Current configuration
show startup-config        # Saved configuration
copy running-config startup-config   # Save config
reload                     # Reboot switch
```

---

### 🔹 Interface & Network

```bash
show interfaces status      # All interface states
show interfaces description # Interface descriptions
show interfaces counters    # RX/TX packet stats
show ip interface brief     # IP summary
show vlan                   # VLAN table
show mac address-table      # MAC-to-port mapping
```

---

### 🔹 Routing

```bash
show ip route               # IPv4 routing table
show ipv6 route             # IPv6 routing table
show ip arp                 # ARP table
show ip ospf neighbor       # OSPF peers
show ip bgp summary         # BGP session summary
```

---

### 🔹 System & Logs

```bash
show processes top          # System CPU/memory
show logging                # Syslog entries
show clock                  # Current time
show users                  # Logged-in users
```

---

### 🔹 Configuration Mode

```bash
configure terminal          # Enter config mode
interface Ethernet1         # Enter interface config
hostname <name>             # Set hostname
ip address 10.0.0.1/24      # Set IP on interface
no shutdown                 # Enable interface
exit                        # Exit to previous mode
```

---

### 🔹 Verification

```bash
ping <IP>                   # Connectivity test
traceroute <IP>             # Path test
show management interfaces   # Mgmt port details
```

## Kill PID when Conflicts
```
sudo lsof -i :50080
kill <pid>
```