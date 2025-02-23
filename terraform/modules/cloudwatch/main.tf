resource "aws_cloudwatch_metric_alarm" "contify" {
  for_each = try(var.alarm_policy, "")

  alarm_name          = format("contify-%s-%s-%s-alarm", var.env, var.aws_region, each.value.name)
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  period              = 120
  statistic           = each.value.statistic
  threshold           = each.value.threshold
  alarm_actions       = each.value.alarm_actions

  dimensions = each.value.dimensions
}
