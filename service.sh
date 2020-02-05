
set_ttl_63()
{
	echo 63 > /proc/sys/net/ipv4/ip_default_ttl
}

filter_interface()
{
	table="$1"
	int="$2"

	iptables -t filter -D OUTPUT  -o "$int" -j $table
	iptables -t filter -D FORWARD -o "$int" -j $table

	iptables -t filter -I OUTPUT  -o "$int" -j $table
	iptables -t filter -I FORWARD -o "$int" -j $table
}

filter_ttl_63()
{
	table="$1"

	if grep -q ttl /proc/net/ip_tables_matches
	then
		iptables -t filter -F $table
		iptables -t filter -N $table

		iptables -t filter -A $table -m ttl --ttl-lt 63 -j REJECT
		iptables -t filter -A $table -m ttl --ttl-eq 63 -j RETURN
		iptables -t filter -A $table -j CONNMARK --set-mark 64

		filter_interface $table 'rmnet_+'
		filter_interface $table 'rev_rmnet_+'

		ip rule add fwmark 64 table 164
		ip route add default dev lo table 164
		ip route flush cache
	fi
}


settings put global tether_dun_required 0

if [ -x "$(command -v iptables)" ]
then
	if grep -q TTL /proc/net/ip_tables_targets
	then
		iptables -t mangle -A POSTROUTING -j TTL --ttl-set 64
	else
		set_ttl_63
		filter_ttl_63 sort_out_interface
	fi
else
	set_ttl_63
fi

