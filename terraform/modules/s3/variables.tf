variable "bucket_name" {
  type    = string
  default = ""
}

variable "env" {
  type    = string
  default = ""
}

variable "aws_region" {
  type    = string
  default = ""
}

variable "elb_account_id" {
  type    = string
  default = ""
}

variable "versioning_enabled" {
  type    = bool
  default = false
}

variable "ownership_controls" {
  type    = bool
  default = false
}

variable "object_ownership" {
  type    = string
  default = ""
}

variable "bucket_policy" {
  type    = bool
  default = false
}

variable "bucket_logging" {
  type    = bool
  default = false
}

variable "bucket_acls" {
  type    = list(string)
  default = [""]
}

variable "bucket_public_access_block" {
  type    = bool
  default = false
}

variable "bucket_public_access_block_logs" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
