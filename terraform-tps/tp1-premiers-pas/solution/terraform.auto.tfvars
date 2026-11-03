cloud_name            = "kolla-aio"
public_key_path       = "~/.ssh/id_rsa.pub"
image_name            = "cirros"
flavor_name           = "m1.tiny"
external_network_name = "public"
subnet_cidr           = "10.10.1.0/24"
dns_nameservers       = ["8.8.8.8"]

sg_rules = {
  ssh  = { protocol = "tcp", port = 22, direction = "ingress", ethertype = "IPv4" }
  icmp = { protocol = "icmp", direction = "ingress", ethertype = "IPv4" }
}