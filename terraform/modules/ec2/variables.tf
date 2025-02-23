variable "env" {
  type    = string
  default = ""
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "vpc_sg_name" {
  type    = string
  default = ""
}

variable "key_pair_enabled" {
  type    = bool
  default = false
}

variable "subnet_id" {
  type    = list(string)
  default = [""]
}

variable "ingress_rule" {
  type    = any
  default = {}
}

variable "egress_rule" {
  type    = any
  default = {}
}

variable "aws_region" {
  type    = string
  default = ""
}

variable "alb_enabled" {
  type    = bool
  default = false
}

variable "alb" {
  type    = any
  default = {}
}

variable "alb_listener" {
  type    = any
  default = {}
}

variable "alb_target_group" {
  type    = any
  default = {}
}

variable "launch_template" {
  type = any
  default = {
    enabled = false
  }
}

variable "autoscaling_group" {
  type    = any
  default = {}
}

variable "aws_availability_zone" {
  type    = string
  default = ""
}

variable "kms_key_id" {
  type    = string
  default = ""
}

variable "autoscaling_policy" {
  type    = any
  default = {}
}

variable "instance" {
  type    = any
  default = {}
}

variable "contify_storage_ebs" {
  type    = any
  default = {}
}

variable "ec2_enabled" {
  type    = bool
  default = false
}

variable "key_pair" {
  type    = any
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
