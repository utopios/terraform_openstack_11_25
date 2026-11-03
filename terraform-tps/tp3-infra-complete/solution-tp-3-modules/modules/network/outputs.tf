output "network_id" {
  description = "ID du réseau"
  value       = openstack_networking_network_v2.this.id
}

output "subnet_id" {
  description = "ID du sous-réseau"
  value       = openstack_networking_subnet_v2.this.id
}

output "router_interface_id" {
  description = "ID de l'interface routeur (null si réseau isolé) : sert aux depends_on"
  value       = var.attach_router ? openstack_networking_router_interface_v2.this[0].id : null
}
