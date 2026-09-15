variable "aws_region" {
  default = "us-east-1"
}

variable "environment" {
  type = string
}

variable "budget_email" {
  type    = string
  default = ""
}
