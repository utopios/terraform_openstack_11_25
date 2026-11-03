# Module network : réseau + sous-réseau + routeur raccordé au réseau externe

resource "openstack_networking_network_v2" "this" {
  name = "${var.name}-net"
}

resource "openstack_networking_subnet_v2" "this" {
  name            = "${var.name}-subnet"
  network_id      = openstack_networking_network_v2.this.id
  cidr            = var.cidr
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
}

resource "openstack_networking_router_v2" "this" {
  name                = "${var.name}-router"
  external_network_id = var.external_network_id
}

resource "openstack_networking_router_interface_v2" "this" {
  router_id = openstack_networking_router_v2.this.id
  subnet_id = openstack_networking_subnet_v2.this.id
}


resource "openstack_networking_secgroup_v2" "this" {
  name        = var.sg_name
  description = "TP1 : SSH et ICMP"
}

resource "openstack_networking_secgroup_rule_v2" "this" {
  for_each = var.sg_rules

  direction         = each.value.direction
  ethertype         = each.value.ethertype
  protocol          = each.value.protocol
  port_range_min    = each.value.port
  port_range_max    = each.value.port
  remote_ip_prefix  = each.value.cidr
  security_group_id = openstack_networking_secgroup_v2.this.id
}