output "contify_security_group_id" {
  value = aws_security_group.contify.id
}

output "instance_id" {
  value = var.ec2_enabled ? aws_instance.contify[0].id : null
}

output "alb_arn" {
  value = var.alb_enabled ? aws_alb.contify[0].arn : null
}

output "alb_target_group_arn" {
  value = var.alb_enabled ? aws_alb_target_group.contify[0].arn : null
}

output "alb_dns_name" {
  value = var.alb_enabled ? aws_alb.contify[0].dns_name : null
}

output "alb_zone_id" {
  value = var.alb_enabled ? aws_alb.contify[0].zone_id : null
}

output "autoscaling_group_arn" {
  value = var.alb_enabled ? aws_autoscaling_group.contify[0].arn : null
}
