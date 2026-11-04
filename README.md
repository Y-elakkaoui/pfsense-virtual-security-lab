# 🔐 pfsense-virtual-security-lab (pfSense + Kali + Ubuntu)

## 📌 Overview
This project is a simple cybersecurity lab built using VMware.

It simulates a small network with:
- pfSense (Firewall)
- Ubuntu Server (Apache Web Server)
- Ubuntu Desktop (Client)
- Kali Linux (Attacker)

The goal is to understand how firewall rules control access between machines, and where they cannot.

---

## 🖥️ Lab Machines

| Machine         | Role                | IP Address        |
|-----------------|---------------------|------------------|
| pfSense         | Firewall / Router   | 10.10.10.1       |
| Ubuntu Server   | Web Server (Apache) | 10.10.10.129     |
| Ubuntu Desktop  | Client              | 10.10.10.128     |
| Kali Linux      | Attacker            | 10.10.10.4       |

---

## 🌐 Network

- LAN: 10.10.10.0/24
- VMware Network: Host-only (VMnet1)
- pfSense acts as the gateway

---

## 🎯 Objectives

- Host a web server using Apache2
- Allow internal users to access it
- Simulate an attacker using Kali Linux
- Block access from the attacker using firewall rules

---

## 🔥 Firewall Rules

Configured on the pfSense LAN interface:

### Allow
- Kali → Web Server (ICMP / ping)
- LAN → any (default rule, covers Ubuntu Desktop → Web Server)

### Block
- Kali → Web Server (HTTP port 80)

---

## 🧪 Testing

### From Ubuntu Desktop
http://10.10.10.129  
✔️ Web server is accessible

### From Kali
```bash
ping 10.10.10.129
nmap 10.10.10.129
```

Expected: port 80 blocked or filtered.

Documented result:
- Ping succeeds
- Port 22 → open
- Port 80 → **open**

⚠️ The scan does not show the intended block.

---

## 🔎 Analysis

Kali and the web server are in the same subnet (10.10.10.0/24) on the same virtual network. Hosts in one subnet talk to each other directly, without going through their gateway. Traffic from Kali to the web server therefore never reaches pfSense, so a rule on pfSense cannot filter it.

The rule itself is configured, but this topology cannot enforce it.

---

## ➡️ Next Steps

1. Move Kali to its own network segment, for example a second pfSense interface on a separate VMnet
2. Create the block rule on that interface
3. Repeat the Nmap scan and document whether port 80 is filtered
4. Change the default pfSense admin password, as the warning in the web interface requests

---

## 📸 Screenshots

### Apache Web Server (Working)
![Apache](screenshots/apache-working.jpeg)

### pfSense Firewall Rules
![pfSense](screenshots/pfsense-rules.jpeg)

### Kali Nmap Scan
![Kali](screenshots/kali-nmap.jpeg)

---

## 🛠️ Tools Used

- VMware Workstation
- pfSense
- Ubuntu Server (Apache2)
- Ubuntu Desktop
- Kali Linux
- Nmap

---

## 📚 What I Learned

- How to configure pfSense firewall rules
- Network segmentation basics, and why it decides what a firewall can see
- Hosting a web server
- Simulating attacks using Kali
- Importance of firewall rule order
- Testing a rule instead of assuming it works

---

## 🧠 Conclusion

This lab shows that a firewall only controls traffic that passes through it. The next step is to segment the network so the rule can take effect, then verify it with a new scan.
