# Module image : une image Glance créée depuis une URL

resource "openstack_images_image_v2" "this" {
  name             = var.name
  image_source_url = var.source_url
  disk_format      = "qcow2"
  container_format = "bare"
  visibility       = "private"

  properties = {
    os_distro = var.os_distro
  }
}
