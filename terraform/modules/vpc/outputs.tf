## Outputs

output "vpc_id" {
  value = aws_vpc.contify.id
}

output "subnet_id" {
  value = aws_subnet.contify.*.id
}

output "private_subnet_id" {
  value = var.private_subnet_enabled ? aws_subnet.contify_private.*.id : null
}

output "route_table_id" {
  value = aws_route_table.contify.*.id
}

output "private_route_table_id" {
  value = var.private_subnet_enabled ? aws_route_table.contify_private.*.id : null
}
