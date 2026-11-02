#!/usr/bin/env bash
# 01 - Preparation OS : interfaces, /etc/hosts, paquets, disques Cinder/Swift
set -euo pipefail
MGMT_IP="192.168.56.10"

echo "=== [01] Detection des interfaces ==="
MGMT_IF=$(ip -o -4 addr show | awk -v ip="$MGMT_IP" '$4 ~ ip"/" {print $2}')
WAN_IF=$(ip -4 route show default | awk '{print $5; exit}')
EXT_IF=""
for i in $(ip -o link show | awk -F': ' '{print $2}' | cut -d'@' -f1); do
  case "$i" in lo|docker*|ovs*|br*|veth*|"$MGMT_IF"|"$WAN_IF") continue ;; esac
  EXT_IF="$i"; break
done
[ -n "$MGMT_IF" ] || { echo "ERREUR : interface management ($MGMT_IP) introuvable"; ip -o -4 addr; exit 1; }
[ -n "$EXT_IF" ]  || { echo "ERREUR : interface externe introuvable"; ip -o link; exit 1; }
echo "WAN : $WAN_IF | Management : $MGMT_IF ($MGMT_IP) | Externe : $EXT_IF"
cat > /etc/openstack-lab.env <<EOT
MGMT_IF=$MGMT_IF
EXT_IF=$EXT_IF
MGMT_IP=$MGMT_IP
VIP=192.168.56.250
EOT

echo "=== [01] Interface externe : pas de DHCP, up (persistant) ==="
cat > /etc/netplan/60-ext-if.yaml <<EOT
network:
  version: 2
  ethernets:
    $EXT_IF:
      dhcp4: false
      dhcp6: false
      optional: true
EOT
chmod 600 /etc/netplan/60-ext-if.yaml
netplan apply || true
ip addr flush dev "$EXT_IF" || true
ip link set dev "$EXT_IF" up
cat > /etc/systemd/system/ext-if-up.service <<EOT
[Unit]
Description=Monte l'interface externe Neutron
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/sbin/ip link set dev $EXT_IF up
[Install]
WantedBy=multi-user.target
EOT
systemctl daemon-reload
systemctl enable ext-if-up.service

echo "=== [01] /etc/hosts (RabbitMQ : hostname -> IP management uniquement) ==="
sed -i '/^127\.0\.[12]\.1[[:space:]].*openstack-aio/d' /etc/hosts
grep -q "^$MGMT_IP openstack-aio" /etc/hosts || echo "$MGMT_IP openstack-aio" >> /etc/hosts

echo "=== [01] Desactivation IPv6 ==="
cat > /etc/sysctl.d/99-disable-ipv6.conf <<EOT
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOT
sysctl --system >/dev/null

echo "=== [01] Paquets systeme ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y python3-dev python3-venv python3-pip libffi-dev gcc libssl-dev \
                   pkg-config libdbus-1-dev libglib2.0-dev \
                   lvm2 parted xfsprogs chrony

echo "=== [01] Disques additionnels (detection par taille) ==="
# disques sans partition ni point de montage, du plus grand au plus petit
mapfile -t FREE < <(lsblk -dnb -o NAME,SIZE,TYPE | awk '$3=="disk"{print $2" "$1}' | sort -rn | awk '{print "/dev/"$2}' | while read d; do
  [ "$(lsblk -n "$d" | wc -l)" -eq 1 ] && ! pvs "$d" >/dev/null 2>&1 && echo "$d"; done)
echo "Disques libres : ${FREE[*]:-aucun}"
if ! vgs cinder-volumes >/dev/null 2>&1; then
  CINDER_DISK="${FREE[0]:?aucun disque libre pour Cinder}"
  echo "Cinder -> $CINDER_DISK"
  pvcreate "$CINDER_DISK"
  vgcreate cinder-volumes "$CINDER_DISK"
  FREE=("${FREE[@]:1}")
fi
if ! blkid -L d0 >/dev/null 2>&1; then
  SWIFT_DISK="${FREE[0]:-}"
  if [ -n "$SWIFT_DISK" ]; then
    echo "Swift -> $SWIFT_DISK (partition KOLLA_SWIFT_DATA, label d0 ; Swift non deploye en aarch64)"
    parted "$SWIFT_DISK" -s -- mklabel gpt mkpart KOLLA_SWIFT_DATA 1 -1
    sleep 2
    mkfs.xfs -f -L d0 "${SWIFT_DISK}1"
  fi
fi
echo "=== [01] Termine ==="
