output "lb_vip_privee" {
  description = "Adresse VIP du load balancer dans le sous-réseau privé"
  value       = openstack_lb_loadbalancer_v2.lb.vip_address
}

output "lb_ip_flottante" {
  description = "IP flottante publique du load balancer"
  value       = openstack_networking_floatingip_v2.lb.address
}

output "url" {
  description = "URL à rafraîchir pour voir la répartition entre les serveurs"
  value       = "http://${openstack_networking_floatingip_v2.lb.address}:${var.lb_port}/"
}

output "membres" {
  description = "Nom -> IP privée de chaque serveur web"
  value = {
    for i, p in openstack_networking_port_v2.web :
    openstack_compute_instance_v2.web[i].name => p.all_fixed_ips[0]
  }
}
