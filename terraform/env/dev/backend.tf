terraform {
  backend "s3" {
    bucket  = "contify-terraform-s3-backend"
    profile = "contify"
    encrypt = true
    key     = "contify/dev/ap-south-1/terraform.tfstate"
    region  = "ap-south-1"
  }
}
