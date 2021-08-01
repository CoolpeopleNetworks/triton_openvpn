Notes:
    * Ensure "ip_spoofing" is enabled on the zone.   This isn't currently possible to do via terraform so it must be done in the adminui.  IMPORTANT: is appears that a zone reboot is required after enabling ip_spoofing.  This step is required on both "external" and private interfaces.
    * It appears that specifying "automatic" for compression in Viscosity prevents comp-lzo from working if specific in the server config (you can't ping the VPN server).   Make sure to explicitly specify "comp-lzo" in Viscosity instead of "automatic".

Links:
    https://www.daveeddy.com/2018/07/05/openvpn-server-setup-with-easyrsa-on-smartos/
