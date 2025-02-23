output "vpc_log_iam_role_arn" {
  value = aws_iam_role.contify_vpc_flow_logs.arn
}

output "ec2_iam_role_name" {
  value = aws_iam_role.contify_ec2.id
}

output "ec2_iam_role_arn" {
  value = aws_iam_role.contify_ec2.arn
}

output "ec2_iam_instance_profile_id" {
  value = aws_iam_instance_profile.contify_ec2.id
}
