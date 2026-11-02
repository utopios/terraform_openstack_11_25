variable "var_2" {
  description = "second variable"
  type        = string
  default     = "default_value"
}

output "var_2" {
  value = var.var_2
}
output "var_1" {
  value = var.var_1
}
