output "image_id" {
  description = "ID de l'image, à passer en image_id des instances"
  value       = openstack_images_image_v2.this.id
}
