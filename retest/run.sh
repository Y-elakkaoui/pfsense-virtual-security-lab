#!/usr/bin/env bash
# Concept retest with Linux network namespaces. nftables stands in for pfSense.
# Phase 1 keeps the attacker in the web server's subnet, phase 2 segments it.
set -uo pipefail
cd "$(dirname "$0")"
mkdir -p evidence

PASS=0; FAIL=0
check() { # check "<description>" <command...>
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "PASS  $d"; PASS=$((PASS+1)); else echo "FAIL  $d"; FAIL=$((FAIL+1)); fi
}
check_not() { # check_not "<description>" <command...>
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "FAIL  $d"; FAIL=$((FAIL+1)); else echo "PASS  $d"; PASS=$((PASS+1)); fi
}
finish() { echo; echo "Result: $PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]; }

sudo apt-get update -qq && sudo apt-get install -y -qq nmap nftables curl >/dev/null
ns() { local n="$1"; shift; sudo ip netns exec "$n" "$@"; }
for n in sw gw web client kali; do sudo ip netns add $n; ns $n ip link set lo up; done

ns sw ip link add br0 type bridge; ns sw ip link set br0 up
plug() { # plug <ns> <addr/len> : connect a namespace to the LAN switch
  sudo ip link add v-$1 type veth peer name p-$1
  sudo ip link set v-$1 netns $1; sudo ip link set p-$1 netns sw
  ns sw ip link set p-$1 master br0; ns sw ip link set p-$1 up
  ns $1 ip addr add $2 dev v-$1; ns $1 ip link set v-$1 up
}
plug gw 10.10.10.1/24; plug web 10.10.10.129/24; plug client 10.10.10.128/24; plug kali 10.10.10.4/24
ns gw sysctl -qw net.ipv4.ip_forward=1
ns web ip route add default via 10.10.10.1
ns client ip route add default via 10.10.10.1
ns kali ip route add default via 10.10.10.1
ns web sh -c 'cd /tmp && nohup python3 -m http.server 80 >/dev/null 2>&1 &'
sleep 2

rules() { # rules <attacker address> : allow ping, block HTTP, and count the blocked packets
  ns gw nft flush ruleset
  ns gw nft add table inet lab
  ns gw nft "add chain inet lab forward { type filter hook forward priority 0; policy accept; }"
  ns gw nft add rule inet lab forward ip saddr $1 ip daddr 10.10.10.129 tcp dport 80 counter drop
}
blocked() { ns gw nft list ruleset | grep -oE 'packets [0-9]+' | awk '{print $2}'; }

# Phase 1: same subnet, as in the original lab
rules 10.10.10.4
ns kali nmap -Pn -p 80 10.10.10.129 | tee evidence/phase1-nmap.txt
P1=$(blocked)

# Phase 2: attacker in its own segment behind the firewall
ns kali ip addr flush dev v-kali; ns kali ip link set v-kali down
sudo ip link add g-kali type veth peer name k-kali
sudo ip link set g-kali netns gw; sudo ip link set k-kali netns kali
ns gw ip addr add 10.10.20.1/24 dev g-kali; ns gw ip link set g-kali up
ns kali ip addr add 10.10.20.4/24 dev k-kali; ns kali ip link set k-kali up
ns kali ip route replace default via 10.10.20.1
rules 10.10.20.4
ns kali ping -c 2 -W 2 10.10.10.129 | tee evidence/phase2-ping.txt
ns kali nmap -Pn -p 80 10.10.10.129 | tee evidence/phase2-nmap.txt
ns client curl -s -o /dev/null -m 5 -w '%{http_code}\n' http://10.10.10.129/ | tee evidence/phase2-client-http.txt
P2=$(blocked)
ns gw nft list ruleset > evidence/firewall-rules.txt

{
  echo "== Phase 1: attacker in the web server's subnet (original topology)"
  check "Port 80 is open despite the block rule" grep -q '80/tcp open' evidence/phase1-nmap.txt
  check "The firewall never saw the traffic (0 packets)" test "$P1" = "0"
  echo
  echo "== Phase 2: attacker in its own segment"
  check "Ping is still allowed"            grep -q ' 0% packet loss' evidence/phase2-ping.txt
  check "Port 80 is now filtered"          grep -q '80/tcp filtered' evidence/phase2-nmap.txt
  check "The block rule counted packets (got $P2)" test "$P2" -gt 0
  check "The client still reaches the web server" grep -q '^200' evidence/phase2-client-http.txt
  finish
} 2>&1 | tee evidence/results.txt
exit "${PIPESTATUS[0]}"
