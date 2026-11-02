#!/bin/bash
# 04-nova-egress.sh — v1.0
# Donne Internet aux VMs Nova sans casser l'accès direct poste → floating IPs.
#   - br-ex reçoit 192.168.57.254 (passerelle du réseau externe Neutron)
#   - NAT (MASQUERADE) de 192.168.57.0/24 vers l'interface de la route par défaut (NIC1 NAT)
#   - gateway du subnet externe : 192.168.57.1 (hôte, ne route pas) → 192.168.57.254
#   - DNS publics sur le subnet privé
#   - security group web-ssh-icmp (ICMP, 22, 80) dans le projet admin
# Idempotent : peut être relancé (vagrant provision --provision-with nova-egress).
set -euo pipefail

EXT_GW_IP="192.168.57.254"
EXT_CIDR="192.168.57.0/24"
DNS1="1.1.1.1"
DNS2="8.8.8.8"
SECGROUP="web-ssh-icmp"

echo "==> [1/6] Script de passerelle /usr/local/sbin/nova-egress.sh"
cat > /usr/local/sbin/nova-egress.sh <<EOF
#!/bin/bash
# Passerelle Internet pour le réseau externe Neutron (floating IPs)
set -euo pipefail

EXT_GW_CIDR="${EXT_GW_IP}/24"
EXT_NET="${EXT_CIDR}"

for i in \$(seq 1 120); do
  ip link show br-ex >/dev/null 2>&1 && break
  sleep 5
done
ip link show br-ex >/dev/null 2>&1 || { echo "br-ex introuvable" >&2; exit 1; }

WAN="\$(ip -4 route show default | awk '{print \$5; exit}')"
[ -n "\$WAN" ] || { echo "aucune route par défaut" >&2; exit 1; }

ip link set br-ex up
ip addr replace "\$EXT_GW_CIDR" dev br-ex
sysctl -q -w net.ipv4.ip_forward=1

iptables -t nat -C POSTROUTING -s "\$EXT_NET" -o "\$WAN" -j MASQUERADE 2>/dev/null \\
  || iptables -t nat -A POSTROUTING -s "\$EXT_NET" -o "\$WAN" -j MASQUERADE
iptables -C FORWARD -s "\$EXT_NET" -o "\$WAN" -j ACCEPT 2>/dev/null \\
  || iptables -I FORWARD 1 -s "\$EXT_NET" -o "\$WAN" -j ACCEPT
iptables -C FORWARD -d "\$EXT_NET" -i "\$WAN" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null \\
  || iptables -I FORWARD 1 -d "\$EXT_NET" -i "\$WAN" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

echo "nova-egress OK : br-ex=\$EXT_GW_CIDR, sortie=\$WAN"
EOF
chmod 755 /usr/local/sbin/nova-egress.sh

echo "==> [2/6] Persistance (sysctl + systemd)"
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-nova-egress.conf
cat > /etc/systemd/system/nova-egress.service <<'EOF'
[Unit]
Description=Passerelle Internet pour les floating IPs Neutron (br-ex 192.168.57.254)
Wants=network-online.target
After=network-online.target docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/nova-egress.sh
RemainAfterExit=yes
TimeoutStartSec=900

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable nova-egress.service
systemctl restart nova-egress.service

echo "==> [3/6] Environnement OpenStack"
set +u
source /opt/kolla/bin/activate
source /etc/kolla/admin-openrc.sh
set -u

EXT_NET=$(openstack network list --external -f value -c Name | head -1)
[ -n "$EXT_NET" ] || { echo "Aucun réseau externe Neutron" >&2; exit 1; }
EXT_SUBNET=$(openstack subnet list --network "$EXT_NET" -f value -c ID | head -1)
PRIV_NET=$(openstack network list --internal -f value -c Name | head -1)
PRIV_SUBNET=$(openstack subnet list --network "$PRIV_NET" -f value -c ID | head -1)
echo "    externe : $EXT_NET ($EXT_SUBNET) / privé : $PRIV_NET ($PRIV_SUBNET)"

echo "==> [4/6] Gateway du subnet externe → $EXT_GW_IP, DNS du subnet privé"
CUR_GW=$(openstack subnet show "$EXT_SUBNET" -f value -c gateway_ip)
if [ "$CUR_GW" != "$EXT_GW_IP" ]; then
  openstack subnet set --gateway "$EXT_GW_IP" "$EXT_SUBNET"
  docker restart neutron_l3_agent
  sleep 30
fi
openstack subnet set --no-dns-nameservers \
  --dns-nameserver "$DNS1" --dns-nameserver "$DNS2" "$PRIV_SUBNET"

echo "==> [5/6] Security group $SECGROUP"
if ! openstack security group show "$SECGROUP" >/dev/null 2>&1; then
  openstack security group create "$SECGROUP" --description "SSH, HTTP, ICMP entrants"
  openstack security group rule create --ingress --protocol icmp "$SECGROUP"
  openstack security group rule create --ingress --protocol tcp --dst-port 22 "$SECGROUP"
  openstack security group rule create --ingress --protocol tcp --dst-port 80 "$SECGROUP"
fi

echo "==> [6/6] Vérification : le routeur Neutron sort sur Internet"
ROUTER_ID=$(openstack router list -f value -c ID | head -1)
for i in $(seq 1 12); do
  if ip netns exec "qrouter-$ROUTER_ID" ip -4 route \
      | grep -q "default via $EXT_GW_IP"; then
    break
  fi
  sleep 5
done
# Kolla 2025.1 : le conteneur l3-agent n'autorise plus "docker exec ... ip netns" (user neutron,
# capabilities reduites) ; les namespaces sont visibles depuis l'hote, on les utilise directement.
ip netns exec "qrouter-$ROUTER_ID" ip -4 route
ip netns exec "qrouter-$ROUTER_ID" ping -c 3 -W 2 8.8.8.8

echo "OK : VMs Nova joignables via floating IP ($EXT_CIDR) et connectées à Internet."
