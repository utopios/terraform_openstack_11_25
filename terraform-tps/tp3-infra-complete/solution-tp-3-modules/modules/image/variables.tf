# Entrées du module image

variable "name" {
  description = "Nom de l'image dans Glance"
  type        = string
}

variable "source_url" {
  description = "URL publique de l'image cloud (qcow2) ; Glance la télécharge lui-même"
  type        = string
}

variable "os_distro" {
  description = "Propriété os_distro de l'image"
  type        = string
  default     = "ubuntu"
}
