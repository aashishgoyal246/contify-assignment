variable "contify_kms_key_alias" {
  type    = string
  default = ""
}

variable "region" {
  type    = string
  default = ""
}

variable "account_id" {
  type    = string
  default = ""
}

variable "sns_topic_arn" {
  type    = string
  default = ""
}

variable "elb_account_id" {
  type    = string
  default = ""
}

variable "vpc_cidr_block" {
  type    = string
  default = ""
}

variable "aws_availability_zones" {
  type    = list(string)
  default = [""]
}

variable "profile" {
  type    = string
  default = ""
}

variable "allowed_ssh_ips" {
  type = list(string)
}

variable "certificate_arn" {
  type    = string
  default = ""
}

variable "contify_ami" {
  type    = string
  default = ""
}

variable "contify_instance_type" {
  type    = string
  default = ""
}

variable "contify_autoscaling_desired_count" {
  type    = number
  default = 1
}

variable "contify_autoscaling_min_count" {
  type    = number
  default = 1
}

variable "contify_autoscaling_max_count" {
  type    = number
  default = 1
}

variable "contify_ebs_size" {
  type    = number
  default = 20
}

variable "database_instance_class" {
  type    = string
  default = ""
}

variable "database_secondary_instance_class" {
  type    = string
  default = ""
}

variable "database_name" {
  type    = string
  default = ""
}

variable "database_username" {
  type    = string
  default = ""
}

variable "database_password" {
  type    = string
  default = ""
}

variable "kms_key_id" {
  type    = string
  default = ""
}

variable "env" {
  type    = string
  default = ""
}

variable "rds_cluster_parameter_group" {
  type    = any
  default = {}
}

variable "database_instance_count" {
  type    = number
  default = 0
}

variable "database_secondary_instance_count" {
  type    = number
  default = 0
}
