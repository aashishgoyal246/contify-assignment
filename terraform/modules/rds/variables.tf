variable "env" {
  type    = string
  default = ""
}

variable "db_subnet_group" {
  type    = any
  default = {}
}

variable "rds_cluster_parameter_group" {
  type    = any
  default = {}
}

variable "rds_cluster" {
  type    = any
  default = {}
}

variable "rds_autoscaling" {
  type = any
  default = {
    enabled = false
  }
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

variable "database_instance_count" {
  type    = number
  default = 0
}

variable "database_instance_class" {
  type    = string
  default = ""
}

variable "database_secondary_instance_count" {
  type    = number
  default = 0
}

variable "database_secondary_instance_class" {
  type    = string
  default = ""
}

variable "serverless" {
  type    = any
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
