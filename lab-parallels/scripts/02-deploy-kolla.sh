#!/usr/bin/env bash
# 02 - Kolla-Ansible 2025.1 (= kolla-ansible 20.x ; images debian-bookworm aarch64), deploiement AIO
set -euo pipefail
source /etc/openstack-lab.env

RELEASE="2025.1"
VENV="/opt/kolla"
INV="/etc/kolla/all-in-one"
ARCH="$(uname -m)"
TAG_SUFFIX=""; [ "$ARCH" = "aarch64" ] && TAG_SUFFIX="-aarch64"
# KVM imbrique Parallels (Apple Silicon) : /dev/kvm existe mais les instances aarch64
# plantent dans le firmware UEFI ("Synchronous Exception") -> emulation QEMU, comme le lab
# VirtualBox des stagiaires. Forcer VIRT_TYPE=kvm pour re-essayer.
VIRT_TYPE="${VIRT_TYPE:-qemu}"
echo "=== [02] arch=$ARCH tag_suffix='$TAG_SUFFIX' virt_type=$VIRT_TYPE ==="

echo "=== [02] Virtualenv + kolla-ansible ${RELEASE} ==="
[ -d "$VENV" ] || python3 -m venv "$VENV"
source "$VENV/bin/activate"
pip install -U pip
pip install 'kolla-ansible~=20.0' 'ansible-core>=2.17,<2.19'

echo "=== [02] Configuration /etc/kolla ==="
mkdir -p /etc/kolla
cp -rn "$VENV/share/kolla-ansible/etc_examples/kolla/"* /etc/kolla/ || true
cp -n  "$VENV/share/kolla-ansible/ansible/inventory/all-in-one" "$INV" || true
kolla-ansible install-deps
grep -q 'keystone_admin_password: [a-zA-Z0-9]' /etc/kolla/passwords.yml || kolla-genpwd

echo "=== [02] globals.yml ==="
cat > /etc/kolla/globals.yml <<EOT
---
workaround_ansible_issue_8743: yes
kolla_base_distro: "debian"
openstack_release: "${RELEASE}"
openstack_tag_suffix: "${TAG_SUFFIX}"

kolla_internal_vip_address: "${VIP}"
network_interface: "${MGMT_IF}"
neutron_external_interface: "${EXT_IF}"
neutron_plugin_agent: "openvswitch"
enable_neutron_provider_networks: "yes"

nova_compute_virt_type: "${VIRT_TYPE}"

enable_cinder: "yes"
enable_cinder_backend_lvm: "yes"

# Swift : aucune image aarch64 publiee -> desactive sur ce lab
enable_swift: "no"

enable_heat: "yes"
enable_horizon: "yes"
EOT

echo "=== [02] Surcharge nova.conf (TCG aarch64 : modele CPU explicite) ==="
mkdir -p /etc/kolla/config
if [ "$VIRT_TYPE" = "qemu" ]; then
# force_config_drive : sur aarch64 Nova ne pose pas les tables SMBIOS "OpenStack Nova" (code x86
# uniquement) ; sans config drive, cloud-init des images Ubuntu ne detecte aucune datasource
# et ne configure ni reseau (DHCP) ni cles SSH. CirrOS n'est pas concerne.
cat > /etc/kolla/config/nova.conf <<EOT
[DEFAULT]
force_config_drive = true

[libvirt]
cpu_mode = custom
cpu_models = cortex-a72
EOT
else
  rm -f /etc/kolla/config/nova.conf
fi

echo "=== [02] bootstrap-servers (installe Docker) ==="
kolla-ansible bootstrap-servers -i "$INV"

echo "=== [02] SDK Docker (venv : interpreteur Ansible en 2025.1, + Python systeme) ==="
pip install 'docker>=6.0.0' dbus-python
/usr/bin/python3 -m pip install --break-system-packages 'docker>=6.0.0' dbus-python || true

echo "=== [02] prechecks + deploy (long : 30-45 min) ==="
kolla-ansible prechecks -i "$INV"
kolla-ansible deploy -i "$INV"
kolla-ansible post-deploy -i "$INV"

echo "=== [02] Client OpenStack ==="
pip install python-openstackclient

echo "=== [02] clouds.yaml pour l'hote (Terraform) ==="
ADMIN_PASS=$(awk '/^keystone_admin_password:/ {print $2}' /etc/kolla/passwords.yml)
mkdir -p /vagrant/terraform
cat > /vagrant/terraform/clouds.yaml <<EOT
clouds:
  kolla-aio:
    auth:
      auth_url: http://${VIP}:5000
      username: admin
      password: ${ADMIN_PASS}
      project_name: admin
      user_domain_name: Default
      project_domain_name: Default
    region_name: RegionOne
    interface: public
    identity_api_version: 3
EOT
echo "=== [02] Deploiement termine. Horizon : http://${VIP} (admin / ${ADMIN_PASS}) ==="
