# Entrées du module compute

variable "name" {
  description = "Nom de la VM ; le port en dérive"
  type        = string
}

variable "image_id" {
  description = "ID de l'image Glance (créée ailleurs, d'où un id et pas un nom)"
  type        = string
}

variable "flavor_id" {
  description = "ID du flavor"
  type        = string
}

variable "key_pair" {
  description = "Nom de la keypair Nova (partagée entre VMs, créée par le root)"
  type        = string
}

variable "network_id" {
  description = "Réseau où brancher la VM"
  type        = string
}

variable "subnet_id" {
  description = "Sous-réseau pour l'IP fixe"
  type        = string
}

variable "security_group_ids" {
  description = "Security groups appliqués au port"
  type        = list(string)
}

variable "user_data" {
  description = "cloud-init optionnel"
  type        = string
  default     = null
}

variable "create_floating_ip" {
  description = "Associer une IP flottante à la VM"
  type        = bool
  default     = false
}

variable "floating_pool" {
  description = "Réseau externe fournissant l'IP flottante"
  type        = string
  default     = ""
}
