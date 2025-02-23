variable "env" {
  type    = string
  default = ""
}

variable "aws_region" {
  type    = string
  default = ""
}

variable "alarm_policy" {
  type    = any
  default = {}
}
