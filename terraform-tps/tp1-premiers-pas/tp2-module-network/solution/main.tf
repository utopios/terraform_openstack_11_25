
# --- Le socle réseau : un appel de module ---
module "network" {
  source = "./modules/network"

  name                = local.prefix
  cidr                = var.subnet_cidr
  dns_nameservers     = var.dns_nameservers
  external_network_id = data.openstack_networking_network_v2.public.id
  sg_name = local.sg_name
  sg_rules = var.sg_rules
}

# --- La VM : les IDs viennent du module network ---
module "vm" {
  source = "./modules/compute"

  name               = local.vm_name
  image_name         = var.image_name
  flavor_name        = var.flavor_name
  public_key         = file(pathexpand(var.public_key_path))
  network_id         = module.network.network_id
  subnet_id          = module.network.subnet_id
  security_group_ids = [module.network.sg_id]

  create_floating_ip = true
  floating_pool      = var.external_network_name

  depends_on = [module.network]
}
