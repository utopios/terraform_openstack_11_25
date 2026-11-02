variable "example_attribute1" {
  description = "An example attribute 1"
  type        = string
  default     = "default_value1"
}
 
variable "all_expect_example_attribute" {
  description = "all_expect_example_attribute"
  type        = list(string)
}
 
 
variable "example_attribute2" {
  description = "An example attribute 2"
  type        = string
  default     = "default_value2"
}
 
resource "null_resource" "example1" {
  example_attribute = var.example_attribute1
  lifecycle {
    create_before_destroy = true
    ignore_changes = [ example_attribute ]
  }
}
resource "null_resource" "example2" {
  lifecycle {
    prevent_destroy = true
  }
  depends_on = [ null_resource.example1 ]
}
 
resource "null_resource" "example3" {
  depends_on = [ null_resource.example1, null_resource.example2 ]
}
 
resource "null_resource" "example4" {
 
  depends_on = [ null_resource.example3 ]
  lifecycle {
    ignore_changes = tolist(setsubtract(list(var.example_attribute2), var))
  }
}