variable "cloud_name" {
  description = "Nom de l'entrée dans clouds.yaml"
  type        = string
}

variable "public_key_path" {
  description = "Chemin de la clé publique SSH"
  type        = string
}

variable "image_name" {
  description = "Image des serveurs web (cloud-init requis)"
  type        = string
}

variable "flavor_name" {
  description = "Flavor des serveurs web"
  type        = string
}

variable "external_network_name" {
  description = "Réseau externe existant (IP flottantes)"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR du sous-réseau privé"
  type        = string
}

variable "dns_nameservers" {
  description = "DNS annoncés par le DHCP"
  type        = list(string)
}

variable "web_count" {
  description = "Nombre de serveurs web derrière le load balancer"
  type        = number
  default     = 2
}

variable "lb_port" {
  description = "Port écouté par le load balancer"
  type        = number
  default     = 80
}

variable "backend_port" {
  description = "Port du service web sur les instances"
  type        = number
  default     = 80
}

variable "lb_algorithm" {
  description = "Algorithme de répartition du pool"
  type        = string
  default     = "ROUND_ROBIN"

  validation {
    condition     = contains(["ROUND_ROBIN", "LEAST_CONNECTIONS", "SOURCE_IP"], var.lb_algorithm)
    error_message = "lb_algorithm : ROUND_ROBIN, LEAST_CONNECTIONS ou SOURCE_IP."
  }
}
