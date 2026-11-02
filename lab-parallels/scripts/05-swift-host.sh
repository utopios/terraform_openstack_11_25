#!/usr/bin/env bash
# 05 - (optionnel, lab Parallels/arm64) Swift "natif" via les paquets Ubuntu, hors Kolla :
#      quay.io n'a pas d'image Swift aarch64. Un seul noeud, 1 replique, device d0 (/dev/sdc1).
#      Enregistre le service object-store dans Keystone -> la demo 04 (Terraform) fonctionne.
set -euo pipefail
source /etc/openstack-lab.env
set +u; source /opt/kolla/bin/activate; source /etc/kolla/admin-openrc.sh; set -u
# Swift desactive dans Kolla : les secrets ne sont pas forcement dans passwords.yml -> valeurs de repli
SWIFT_PASS=$(awk '/^swift_keystone_password:/ {print $2}' /etc/kolla/passwords.yml); SWIFT_PASS="${SWIFT_PASS:-SwiftLabPass2025}"
HASH=$(awk '/^swift_hash_path_suffix:/ {print $2}' /etc/kolla/passwords.yml); HASH="${HASH:-labswifthash}"

echo "=== [05] Paquets Swift ==="
export DEBIAN_FRONTEND=noninteractive
apt-get install -y swift swift-proxy swift-account swift-container swift-object python3-keystonemiddleware xfsprogs

echo "=== [05] Device d0 ==="
mkdir -p /srv/node/d0
grep -q "LABEL=d0 " /etc/fstab || echo "LABEL=d0 /srv/node/d0 xfs noatime 0 2" >> /etc/fstab
mountpoint -q /srv/node/d0 || mount /srv/node/d0
chown -R swift:swift /srv/node
mkdir -p /var/cache/swift && chown -R swift:swift /var/cache/swift

echo "=== [05] Configuration ==="
cat > /etc/swift/swift.conf <<EOT
[swift-hash]
swift_hash_path_suffix = ${HASH}
swift_hash_path_prefix = ${HASH}
[storage-policy:0]
name = Policy-0
default = yes
EOT
for svc in account:6202 container:6201 object:6200; do
  n=${svc%%:*}; p=${svc##*:}
  cat > /etc/swift/${n}-server.conf <<EOT
[DEFAULT]
bind_ip = ${MGMT_IP}
bind_port = ${p}
user = swift
swift_dir = /etc/swift
devices = /srv/node
mount_check = true
[pipeline:main]
pipeline = healthcheck recon ${n}-server
[app:${n}-server]
use = egg:swift#${n}
[filter:healthcheck]
use = egg:swift#healthcheck
[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift
EOT
done
cat > /etc/swift/proxy-server.conf <<EOT
[DEFAULT]
bind_ip = ${MGMT_IP}
bind_port = 8080
user = swift
swift_dir = /etc/swift
[pipeline:main]
pipeline = catch_errors gatekeeper healthcheck proxy-logging cache listing_formats bulk ratelimit authtoken keystoneauth copy container-quotas account-quotas slo dlo versioned_writes symlink proxy-logging proxy-server
[app:proxy-server]
use = egg:swift#proxy
account_autocreate = true
[filter:keystoneauth]
use = egg:swift#keystoneauth
operator_roles = admin,member,_member_
[filter:authtoken]
paste.filter_factory = keystonemiddleware.auth_token:filter_factory
www_authenticate_uri = http://${VIP}:5000
auth_url = http://${VIP}:5000
memcached_servers = ${MGMT_IP}:11211
auth_type = password
project_domain_id = default
user_domain_id = default
project_name = service
username = swift
password = ${SWIFT_PASS}
delay_auth_decision = true
[filter:cache]
use = egg:swift#memcache
memcache_servers = ${MGMT_IP}:11211
[filter:catch_errors]
use = egg:swift#catch_errors
[filter:gatekeeper]
use = egg:swift#gatekeeper
[filter:healthcheck]
use = egg:swift#healthcheck
[filter:proxy-logging]
use = egg:swift#proxy_logging
[filter:listing_formats]
use = egg:swift#listing_formats
[filter:bulk]
use = egg:swift#bulk
[filter:ratelimit]
use = egg:swift#ratelimit
[filter:copy]
use = egg:swift#copy
[filter:container-quotas]
use = egg:swift#container_quotas
[filter:account-quotas]
use = egg:swift#account_quotas
[filter:slo]
use = egg:swift#slo
[filter:dlo]
use = egg:swift#dlo
[filter:versioned_writes]
use = egg:swift#versioned_writes
[filter:symlink]
use = egg:swift#symlink
EOT

echo "=== [05] Anneaux ==="
cd /etc/swift
for svc in account:6202 container:6201 object:6200; do
  n=${svc%%:*}; p=${svc##*:}
  if [ ! -f ${n}.ring.gz ]; then
    swift-ring-builder ${n}.builder create 10 1 1
    swift-ring-builder ${n}.builder add --region 1 --zone 1 --ip ${MGMT_IP} --port ${p} --device d0 --weight 100
    swift-ring-builder ${n}.builder rebalance
  fi
done
chown -R root:swift /etc/swift; chmod -R g+r /etc/swift

echo "=== [05] Keystone : utilisateur, service, endpoints ==="
openstack user show swift >/dev/null 2>&1 || openstack user create --domain default --password "$SWIFT_PASS" swift
openstack user set --password "$SWIFT_PASS" swift
openstack role add --project service --user swift admin
openstack service show object-store >/dev/null 2>&1 || openstack service create --name swift --description "OpenStack Object Storage" object-store
for iface in public internal admin; do
  openstack endpoint list --service object-store --interface $iface -f value | grep -q . || \
    openstack endpoint create --region RegionOne object-store $iface "http://${MGMT_IP}:8080/v1/AUTH_%(project_id)s"
done

echo "=== [05] Services ==="
systemctl enable --now swift-account swift-container swift-object swift-proxy
systemctl restart swift-account swift-container swift-object swift-proxy
sleep 3
systemctl is-active swift-account swift-container swift-object swift-proxy
echo "=== [05] Test ==="
openstack container create lab-swift-test -f value -c container
openstack object list lab-swift-test -f value
openstack container delete lab-swift-test
echo "=== [05] Swift OK (endpoint http://${MGMT_IP}:8080) ==="
