# Module network : réseau + sous-réseau + (optionnel) raccordement à un routeur existant.
# Le routeur n'est PAS créé ici : au TP3 un seul routeur sert deux réseaux,
# il appartient donc au root, et chaque appel du module y ajoute une interface.

resource "openstack_networking_network_v2" "this" {
  name = var.name
}

resource "openstack_networking_subnet_v2" "this" {
  name            = var.subnet_name
  network_id      = openstack_networking_network_v2.this.id
  cidr            = var.cidr
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
}

# count sur un booléen connu au plan, PAS sur var.router_id : l'id du routeur
# n'est connu qu'à l'apply et Terraform refuserait de calculer le count.
resource "openstack_networking_router_interface_v2" "this" {
  count = var.attach_router ? 1 : 0

  router_id = var.router_id
  subnet_id = openstack_networking_subnet_v2.this.id
}
