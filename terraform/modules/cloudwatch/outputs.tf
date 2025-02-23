output "alarm_name" {
  value = {
    for k, v in aws_cloudwatch_metric_alarm.contify : k => v.id
  }
}
