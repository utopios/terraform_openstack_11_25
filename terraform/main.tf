resource "openstack_networking_network_v2" "example_network" {
  name = "example-network"
}
resource "openstack_networking_subnet_v2" "example_subnet" {
  name = "example-subnet"
  network_id = openstack_networking_network_v2.example_network.id
  cidr = "192.168.0.0/24"
}

resource "openstack_compute_instance_v2" "basic" {
  name            = "basic"
  image_name        = "cirros"
  flavor_name       = "m1.tiny"
  key_pair        = "demo"
  security_groups = ["web-ssh-icmp"]

  metadata = {
    this = "that"
  }

  network {
    name = openstack_networking_network_v2.example_network.name
  }
  provisioner "remote-exec" {
    inline = ["echo ${self.network.0.name}"]
  }
}