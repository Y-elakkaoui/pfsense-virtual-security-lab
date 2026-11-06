# pfSense Firewall Lab

A virtual network in VMware Workstation that tests how pfSense firewall rules control traffic between hosts, and where a firewall cannot enforce them.

> **Status:** Rules configured and tested. The documented scan shows that the HTTP block does not take effect, because the attacker and the web server share a subnet. Network segmentation is the next step.

> **Kurzfassung (DE):** Firewall-Lab in VMware mit pfSense, Ubuntu und Kali Linux. HTTP von Kali zum Webserver sollte blockiert werden, der Nmap-Scan zeigt Port 80 aber weiterhin offen: Beide Hosts liegen im selben Subnetz, ihr Verkehr läuft also nicht über die Firewall. Als Nächstes kommt Kali in ein eigenes Netzsegment, danach wird der Scan wiederholt.

![pfSense firewall rules](screenshots/pfsense-rules.jpeg)

## Lab environment

| Machine | Role | IP address |
|---|---|---|
| pfSense | Firewall and gateway | 10.10.10.1 |
| Ubuntu Server | Web server (Apache2) | 10.10.10.129 |
| Ubuntu Desktop | Client | 10.10.10.128 |
| Kali Linux | Attacker | 10.10.10.4 |

- **LAN:** 10.10.10.0/24
- **VMware network:** Host-only (VMnet1)

## Objectives

- Host a web server with Apache2
- Allow internal clients to reach it
- Simulate an attacker with Kali Linux
- Block the attacker's HTTP access with a firewall rule

## Firewall rules

Configured on the pfSense LAN interface:

| Action | Source | Destination | Traffic |
|---|---|---|---|
| Allow | Kali Linux | Web server | ICMP (ping) |
| Block | Kali Linux | Web server | HTTP (port 80) |
| Allow | LAN | Any | All (default rule, covers Ubuntu Desktop to web server) |

## Test results

| Test | Source | Expected | Result |
|---|---|---|---|
| `http://10.10.10.129` | Ubuntu Desktop | Web server reachable | Reachable |
| `ping 10.10.10.129` | Kali Linux | Allowed | Succeeds |
| `nmap 10.10.10.129` | Kali Linux | Port 80 blocked or filtered | **Port 80 open**, port 22 open |

The scan does not show the intended block.

## Root cause

Kali Linux and the web server are in the same subnet (10.10.10.0/24) on the same virtual network. Hosts in one subnet communicate directly, without going through their gateway. Traffic from Kali Linux to the web server therefore never reaches pfSense, so a rule on pfSense cannot filter it.

The rule itself is configured, but this topology cannot enforce it.

## Next steps

1. Move Kali Linux to its own network segment, for example a second pfSense interface on a separate VMnet
2. Create the block rule on that interface
3. Repeat the Nmap scan and document whether port 80 is filtered
4. Change the default pfSense admin password, as the warning in the web interface requests

## Evidence

### Apache web server reachable

![Apache web server](screenshots/apache-working.jpeg)

### Nmap scan from Kali Linux

![Nmap scan from Kali Linux](screenshots/kali-nmap.jpeg)

## Tools

VMware Workstation, pfSense, Ubuntu Server (Apache2), Ubuntu Desktop, Kali Linux, Nmap

## Key takeaways

- Network segmentation decides which traffic a firewall can see. A firewall only controls traffic that passes through it.
- A rule has to be tested. A configured rule is not yet a working rule.
- The order of firewall rules matters.
