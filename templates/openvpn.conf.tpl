# OpenVPN Server Config
port 1194
proto udp
management localhost 7505
dev tun
comp-lzo
persist-key
persist-tun
verb 3
#link-mtu 1500
topology subnet

# keys and certs
ca ca.crt
cert server.crt
key server.key
dh dh2048.pem

# This will be the internal tun0 connection IP - should match ipnat.conf
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt

# This will send all of a client's traffic to the private vlans through the tunnel
#push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 10.100.100.1"
#push "dhcp-option DOMAIN-SEARCH rapture.com"
push "dhcp-option DOMAIN ${domain}"
keepalive 10 120

# Push routes to the private network
push "route 192.168.128.0 255.255.252.0"

# connect script
#script-security 2
#client-connect ./client-connect
