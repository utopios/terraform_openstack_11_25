# TP 3 — solution découpée en modules
#
# Le root ne garde que ce qui est unique (flavor, keypair, routeur) et
# assemble quatre modules réutilisables :
#   modules/image     x2  (bionic, jammy)
#   modules/network   x2  (public, private) raccordés au MÊME routeur
#   modules/security  x2  (règles VM1, règles VM2)
#   modules/compute   x2  (VM1 avec IP flottante, VM2 sans)
# Même infrastructure que la solution monolithique : 24 ressources.

# --- Images Glance : un module, deux appels ---
module "image_bionic" {
  source = "./modules/image"

  name       = local.image_bionic_name
  source_url = var.image_url_bionic
}

module "image_jammy" {
  source = "./modules/image"

  name       = local.image_jammy_name
  source_url = var.image_url_jammy
}

# --- Ressources uniques : restent dans le root ---
resource "openstack_compute_flavor_v2" "flavor" {
  name  = local.flavor_name
  vcpus = var.flavor_vcpus
  ram   = var.flavor_ram_mb
  disk  = var.flavor_disk_gb
}

resource "openstack_compute_keypair_v2" "key" {
  name       = local.key_name
  public_key = file(pathexpand(var.public_key_path))
}

resource "openstack_networking_router_v2" "router" {
  name                = local.router_name
  external_network_id = data.openstack_networking_network_v2.public.id
}

# --- Réseaux : chaque appel ajoute une interface au routeur ---
module "net_public" {
  source = "./modules/network"

  name            = local.net_public_name
  subnet_name     = local.subnet_public_name
  cidr            = var.public_subnet_cidr
  dns_nameservers = var.dns_nameservers
  router_id       = openstack_networking_router_v2.router.id
}

module "net_private" {
  source = "./modules/network"

  name            = local.net_private_name
  subnet_name     = local.subnet_private_name
  cidr            = var.private_subnet_cidr
  dns_nameservers = var.dns_nameservers
  router_id       = openstack_networking_router_v2.router.id
}

# --- Security groups : les règles sont des données ---
module "sg_vm1" {
  source = "./modules/security"

  name        = local.sg_vm1_name
  description = "TP3 VM1 : HTTP, SSH, ICMP"
  rules = [
    { protocol = "tcp", port_min = 80, port_max = 80 },
    { protocol = "tcp", port_min = 22, port_max = 22 },
    { protocol = "icmp" },
  ]
}

module "sg_vm2" {
  source = "./modules/security"

  name        = local.sg_vm2_name
  description = "TP3 VM2 : ICMP + SSH depuis le reseau public"
  rules = [
    { protocol = "icmp" },
    { protocol = "tcp", port_min = 22, port_max = 22, remote_ip_prefix = var.public_subnet_cidr },
  ]
}

# --- VM1 : 18.04 + nginx, réseau public, IP flottante ---
module "vm1" {
  source = "./modules/compute"

  name               = local.vm1_name
  image_id           = module.image_bionic.image_id
  flavor_id          = openstack_compute_flavor_v2.flavor.id
  key_pair           = openstack_compute_keypair_v2.key.name
  network_id         = module.net_public.network_id
  subnet_id          = module.net_public.subnet_id
  security_group_ids = [module.sg_vm1.sg_id]
  user_data          = local.vm1_user_data

  create_floating_ip = true
  floating_pool      = var.external_network_name

  depends_on = [module.net_public]
}

# --- VM2 : 22.04, réseau privé, pas d'IP flottante ---
module "vm2" {
  source = "./modules/compute"

  name               = local.vm2_name
  image_id           = module.image_jammy.image_id
  flavor_id          = openstack_compute_flavor_v2.flavor.id
  key_pair           = openstack_compute_keypair_v2.key.name
  network_id         = module.net_private.network_id
  subnet_id          = module.net_private.subnet_id
  security_group_ids = [module.sg_vm2.sg_id]

  depends_on = [module.net_private]
}
