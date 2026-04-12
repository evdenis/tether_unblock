#!/system/bin/sh

# Disable tethering detection properties.
resetprop tether_dun_required 0
resetprop net.tethering.noprovisioning true
resetprop tether_entitlement_check_state 0

# Wait for boot to complete before applying iptables rules,
# since network interfaces may not be up yet.
until [ "$(getprop sys.boot_completed)" = 1 ]; do
	sleep 1
done

# Increment TTL/HL on tethering interfaces so that tethered traffic
# appears to originate from this device.
# Rules are added for all interfaces unconditionally — iptables matches
# on interface name regardless of whether it exists yet, so rules will
# take effect when tethering is enabled and the interface is created.
# rndis0: USB tethering, wlan0/wlan1/ap0: Wi-Fi hotspot, bt-pan: Bluetooth.
HAS_IPTABLES=false
HAS_IP6TABLES=false
[ -x "$(command -v iptables)" ] && HAS_IPTABLES=true
[ -x "$(command -v ip6tables)" ] && HAS_IP6TABLES=true

for IFACE in rndis0 wlan0 wlan1 wlan2 wlan3 ncm0 ncm1 ncm2 ncm3 ap0 bt-pan; do
	if $HAS_IPTABLES; then
		iptables  -t mangle -A PREROUTING  -i "$IFACE" -j TTL --ttl-inc 1
		iptables  -t mangle -I POSTROUTING -o "$IFACE" -j TTL --ttl-inc 1
	fi

	if $HAS_IP6TABLES; then
		ip6tables -t mangle -A PREROUTING  ! -p icmpv6 -i "$IFACE" -j HL --hl-inc 1
		ip6tables -t mangle -I POSTROUTING ! -p icmpv6 -o "$IFACE" -j HL --hl-inc 1
	fi
done

# Fallback: if the kernel lacks TTL/HL iptables targets, set default
# values via /proc so at least traffic from this device has correct values.
if ! $HAS_IPTABLES || ! grep -q TTL /proc/net/ip_tables_targets 2>/dev/null; then
	echo 64 > /proc/sys/net/ipv4/ip_default_ttl
fi
if ! $HAS_IP6TABLES || ! grep -q HL /proc/net/ip6_tables_targets 2>/dev/null; then
	echo 64 > /proc/sys/net/ipv6/conf/all/hop_limit
fi
