variable "environment" {
  description = "The environment for the deployment"
  type        = string
  default     = "development"
  validation {
    condition = contains(["production", "development"], var.environment)
    error_message = "The environment must be production or development"
  }
}

variable "type" {
  description = "The type of deployment"
  type        = string
  default     = "standard"
  validation {
    condition = contains(["small", "large"], var.type)
    error_message = "The type must be small or large"
  }
}

// Uniquement pour l'exercice, dans un projet réel, on utilisera autre notions pour le calcule
variable "size" {
  description = "The size of the deployment"
  default = var.type == "small" ? "micro" : "big"
}

variable "names" {
  type    = list(string)
  default = ["Alice", "Bob", "Charlie"]
}

output "names" {
  value = [for name in var.names : "Welcome, ${name}!"]
}
