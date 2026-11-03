# Entrées du module network

variable "name" {
  description = "Nom du réseau"
  type        = string
}

variable "subnet_name" {
  description = "Nom du sous-réseau"
  type        = string
}

variable "cidr" {
  description = "CIDR du sous-réseau"
  type        = string
}

variable "dns_nameservers" {
  description = "DNS annoncés par le DHCP"
  type        = list(string)
  default     = ["8.8.8.8"]
}

variable "attach_router" {
  description = "Raccorder le sous-réseau à un routeur (false = réseau isolé)"
  type        = bool
  default     = true
}

variable "router_id" {
  description = "Routeur auquel raccorder le sous-réseau (ignoré si attach_router = false)"
  type        = string
  default     = null
}
