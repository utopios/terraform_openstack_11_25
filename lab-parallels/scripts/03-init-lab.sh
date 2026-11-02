#!/usr/bin/env bash
# 03 - Ressources de base : reseaux, routeur, image CirrOS, flavors, security group
set -euo pipefail
source /etc/openstack-lab.env
set +u; source /opt/kolla/bin/activate; source /etc/kolla/admin-openrc.sh; set -u
ARCH="$(uname -m)"

echo "=== [03] Attente de Keystone (VIP ${VIP}) ==="
for i in $(seq 1 60); do curl -sm 5 -o /dev/null "http://${VIP}:5000" && break; sleep 5; done
curl -sm 5 -o /dev/null "http://${VIP}:5000" || { echo "ERREUR : Keystone injoignable"; exit 1; }

echo "=== [03] Reseau externe 'public' (flat physnet1 -> ${EXT_IF}) ==="
if ! openstack network show public >/dev/null 2>&1; then
  openstack network create --external --provider-network-type flat --provider-physical-network physnet1 public
  openstack subnet create --network public --subnet-range 192.168.57.0/24 \
    --allocation-pool start=192.168.57.100,end=192.168.57.200 --gateway 192.168.57.1 --no-dhcp public-subnet
fi

echo "=== [03] Reseau prive + routeur ==="
if ! openstack network show private >/dev/null 2>&1; then
  openstack network create private
  openstack subnet create --network private --subnet-range 10.0.0.0/24 --dns-nameserver 8.8.8.8 private-subnet
  openstack router create router1
  openstack router set router1 --external-gateway public
  openstack router add subnet router1 private-subnet
fi

echo "=== [03] Image CirrOS (${ARCH}) ==="
if ! openstack image show cirros >/dev/null 2>&1; then
  CIRROS_ARCH="x86_64"; [ "$ARCH" = "aarch64" ] && CIRROS_ARCH="aarch64"
  curl -fsSL -o /tmp/cirros.img "https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-${CIRROS_ARCH}-disk.img"
  PROPS=(); [ "$ARCH" = "aarch64" ] && PROPS=(--property hw_firmware_type=uefi --property hw_machine_type=virt)
  openstack image create --disk-format qcow2 --container-format bare --public "${PROPS[@]}" --file /tmp/cirros.img cirros
fi

echo "=== [03] Flavors ==="
openstack flavor show m1.tiny  >/dev/null 2>&1 || openstack flavor create --vcpus 1 --ram 512  --disk 1  m1.tiny
openstack flavor show m1.small >/dev/null 2>&1 || openstack flavor create --vcpus 1 --ram 1024 --disk 10 m1.small

echo "=== [03] Security group 'allow-ssh-icmp' ==="
if ! openstack security group show allow-ssh-icmp >/dev/null 2>&1; then
  openstack security group create allow-ssh-icmp
  openstack security group rule create --proto icmp allow-ssh-icmp
  openstack security group rule create --proto tcp --dst-port 22 allow-ssh-icmp
fi
echo "=== [03] Lab pret ==="
openstack service list
