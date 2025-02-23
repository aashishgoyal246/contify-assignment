variable "cidr_block" {
  type    = string
  default = ""
}

variable "enable_dns_support" {
  type    = bool
  default = true
}

variable "enable_dns_hostnames" {
  type    = bool
  default = true
}

variable "vpc_log_iam_role_arn" {
  type    = string
  default = ""
}

variable "private_subnet_enabled" {
  type    = bool
  default = false
}

variable "log_group_prefix" {
  type    = string
  default = ""
}

variable "subnet_tag" {
  type    = string
  default = ""
}

variable "public_subnet_tags" {
  type    = any
  default = {}
}

variable "private_subnet_tags" {
  type    = any
  default = {}
}

variable "aws_availability_zones" {
  type    = list(string)
  default = [""]
}

variable "tags" {
  type    = map(string)
  default = {}
}
