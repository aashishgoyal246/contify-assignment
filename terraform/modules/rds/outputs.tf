output "rds_cluster_id" {
  value = var.rds_cluster.cluster_identifier
}

output "rds_master_username" {
  value = aws_rds_cluster.contify.master_username
}

output "rds_master_password" {
  value = aws_rds_cluster.contify.master_password
}

output "rds_endpoint" {
  value = aws_rds_cluster.contify.endpoint
}

output "rds_reader_endpoint" {
  value = aws_rds_cluster.contify.reader_endpoint
}

output "rds_port" {
  value = aws_rds_cluster.contify.port
}

output "rds_database_name" {
  value = aws_rds_cluster.contify.database_name
}
