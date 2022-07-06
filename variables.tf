# Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources."
  type    = string
  default = "ap-southeast-1"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type    = string
  default = "10.10.0.0/16"
}

variable "private_subnets" {
  description = "A list of private subnets inside the VPC"
  type    = list(string)
  default = ["10.10.101.0/24", "10.10.102.0/24", "10.10.103.0/24"]
}
