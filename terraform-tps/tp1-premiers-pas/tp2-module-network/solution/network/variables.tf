# Entrées du module network

variable "name" {
  description = "Nom de base : réseau, sous-réseau et routeur en dérivent"
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

variable "external_network_id" {
  description = "ID du réseau externe (passerelle du routeur)"
  type        = string
}

variable "sg_rules" {
  description = "Règles entrantes du security group, une entrée par règle"
  type = map(object({
    protocol  = string
    port      = optional(number)              # null pour ICMP
    cidr      = optional(string, "0.0.0.0/0")
    direction = optional(string, "ingress")   # "ingress" ou "egress"
    ethertype = optional(string, "IPv4")       # "IPv4" ou "IPv6"
  }))
}

variable "sg_name" {
  description = "Nom du security group"
  type        = string
}