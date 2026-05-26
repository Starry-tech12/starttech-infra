variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "environment" {
  type    = string
  default = "production"
}

variable "ami_id" {
  type        = string
  default     = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS x86_64 in us-east-1. Adjust for your region if different.
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}