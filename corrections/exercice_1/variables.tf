variable "first_name" {
    description = "First name of the user"
    type        = string
    default     = "John"
    validation {
        condition     = length(var.first_name) > 3
        error_message = "First name must be longer than 3 characters"
    }
}

variable "last_name" {
  description = "the last name of the student"
  type = string
}

variable "age" {
  description = "the age of the student"
  type = number
  validation {
    condition = var.age >= 14 && var.age <= 100
    error_message = "Age must be gt 14 and lt 100"
  }
}

variable "is_student" {
  description = "Whether the person is a student"
  type = bool
  default = false
}
variable "courses" {
  description = "the list of courses the student is taking"
  type = list(string)
  default = [ "Math", "Science" ]
}


variable "grades" {
  description = "the grades of the student in each course"
  type = map(number)
  default = {
    "Math" = 90,
    "Science" = 90
  }
}


variable "student" {
  description = "The details of the student"
  type = object({
    first_name = string
    last_name = string
    age = number
    is_student = bool
    courses = list(string)
    grades = map(number)
  })
 
  default = {
    first_name = "value"
    last_name = "value"
    age = 20
    is_student = true
    courses = ["Math", "Science"]   
    grades = {
      "Math" = 90,
      "Science" = 90
    }
  }
}