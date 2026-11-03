# Exercice 7 (support p.49) — Load balancer devant deux serveurs web
#
# Chaîne : réseau + sous-réseau -> routeur -> N instances nginx
#          -> load balancer (VIP dans le sous-réseau) -> listener HTTP
#          -> pool round-robin -> un membre par instance -> IP flottante sur la VIP
#
# Prérequis côté cloud : le service load-balancer (Octavia) doit être
# présent dans le catalogue Keystone (`openstack loadbalancer list`).

# --- Réseau privé + sous-réseau ---
resource "openstack_networking_network_v2" "net" {
  name = local.net_name
}

resource "openstack_networking_subnet_v2" "subnet" {
  name            = local.subnet_name
  network_id      = openstack_networking_network_v2.net.id
  cidr            = var.subnet_cidr
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
}

# --- Raccordement au réseau externe ---
resource "openstack_networking_router_v2" "router" {
  name                = local.router_name
  external_network_id = data.openstack_networking_network_v2.public.id
}

resource "openstack_networking_router_interface_v2" "iface" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.subnet.id
}

# --- Security group : HTTP (depuis le LB et l'extérieur), SSH, ICMP ---
resource "openstack_networking_secgroup_v2" "sg" {
  name        = local.sg_name
  description = "Exercice 7 : HTTP, SSH, ICMP"
}

resource "openstack_networking_secgroup_rule_v2" "rules" {
  for_each = {
    http = { protocol = "tcp", port = var.backend_port }
    ssh  = { protocol = "tcp", port = 22 }
    icmp = { protocol = "icmp", port = null }
  }

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = each.value.protocol
  port_range_min    = each.value.port
  port_range_max    = each.value.port
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg.id
}

# --- Keypair ---
resource "openstack_compute_keypair_v2" "key" {
  name       = local.key_name
  public_key = file(pathexpand(var.public_key_path))
}

# --- Les serveurs web : un port + une instance par index ---
resource "openstack_networking_port_v2" "web" {
  count = var.web_count

  name               = "${local.web_name}-${count.index + 1}-port"
  network_id         = openstack_networking_network_v2.net.id
  security_group_ids = [openstack_networking_secgroup_v2.sg.id]

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.subnet.id
  }
}

resource "openstack_compute_instance_v2" "web" {
  count = var.web_count

  name        = "${local.web_name}-${count.index + 1}"
  image_name  = var.image_name
  flavor_name = var.flavor_name
  key_pair    = openstack_compute_keypair_v2.key.name
  user_data   = local.web_user_data

  network {
    port = openstack_networking_port_v2.web[count.index].id
  }

  depends_on = [openstack_networking_router_interface_v2.iface]
}

# --- Load balancer : la VIP est prise dans le sous-réseau privé ---
resource "openstack_lb_loadbalancer_v2" "lb" {
  name          = local.lb_name
  vip_subnet_id = openstack_networking_subnet_v2.subnet.id

  depends_on = [openstack_networking_router_interface_v2.iface]
}

# --- Listener : ce que le LB écoute ---
resource "openstack_lb_listener_v2" "http" {
  name            = local.listener_name
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb.id
  protocol        = "HTTP"
  protocol_port   = var.lb_port
}

# --- Pool : vers qui le listener distribue ---
resource "openstack_lb_pool_v2" "web" {
  name        = local.pool_name
  listener_id = openstack_lb_listener_v2.http.id
  protocol    = "HTTP"
  lb_method   = var.lb_algorithm
}

# --- Membres : un par serveur web, adresse = IP fixe du port ---
resource "openstack_lb_member_v2" "web" {
  count = var.web_count

  name          = "${local.web_name}-${count.index + 1}"
  pool_id       = openstack_lb_pool_v2.web.id
  subnet_id     = openstack_networking_subnet_v2.subnet.id
  address       = openstack_networking_port_v2.web[count.index].all_fixed_ips[0]
  protocol_port = var.backend_port
}

# --- Health monitor (bonus) : retire un membre qui ne répond plus ---
resource "openstack_lb_monitor_v2" "http" {
  name        = local.monitor_name
  pool_id     = openstack_lb_pool_v2.web.id
  type        = "HTTP"
  url_path    = "/"
  delay       = 10
  timeout     = 5
  max_retries = 3
}

# --- IP flottante sur la VIP du load balancer (pas sur les instances) ---
resource "openstack_networking_floatingip_v2" "lb" {
  pool = var.external_network_name
}

resource "openstack_networking_floatingip_associate_v2" "lb" {
  floating_ip = openstack_networking_floatingip_v2.lb.address
  port_id     = openstack_lb_loadbalancer_v2.lb.vip_port_id
}
