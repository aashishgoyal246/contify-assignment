output "contify_security_group_id" {
  value = module.ec2.contify_security_group_id
}

output "logs_bucket" {
  value = "s3://${module.contify_logs_s3.s3_bucket_name}/"
}

output "ssh_public_key" {
  value = "files/envs/${var.env}/id_rsa-contify.pub"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "subnet_id" {
  value = module.vpc.subnet_id
}

output "vpc_private_subnet_id" {
  value = module.vpc.private_subnet_id
}

output "rds_cluster_id" {
  value = module.rds.rds_cluster_id
}

output "rds_endpoint" {
  value = module.rds.rds_endpoint
}

output "rds_reader_endpoint" {
  value = module.rds.rds_reader_endpoint
}

output "rds_port" {
  value = module.rds.rds_port
}

output "rds_database_name" {
  value = module.rds.rds_database_name
}
