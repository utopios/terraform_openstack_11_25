terraform {
    required_version = ">= 1.0.0"
    required_providers {
        openstack = {
            source  = "terraform-provider-openstack/openstack"
            version = ">= 2.1"
        }
    }
}

provider openstack {
    cloud = "kolla-aio"
}