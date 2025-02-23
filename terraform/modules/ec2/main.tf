resource "aws_security_group" "contify" {
  name   = var.vpc_sg_name
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "ingress_rule" {
  for_each = var.ingress_rule

  type                     = "ingress"
  description              = each.value.description
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  self                     = try(each.value.self, null)
  cidr_blocks              = try(each.value.cidr_blocks, null)
  source_security_group_id = try(each.value.source_security_group_id, null)
  security_group_id        = aws_security_group.contify.id
}

resource "aws_security_group_rule" "egress_rule" {
  for_each = var.egress_rule

  type                     = "egress"
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  cidr_blocks              = try(each.value.cidr_blocks, null)
  source_security_group_id = try(each.value.source_security_group_id, null)
  security_group_id        = aws_security_group.contify.id
}

resource "aws_alb_target_group" "contify" {
  count = var.alb_enabled ? 1 : 0

  name                          = var.alb_target_group.name
  port                          = var.alb_target_group.port
  protocol                      = var.alb_target_group.protocol
  proxy_protocol_v2             = var.alb_target_group.proxy_protocol_v2
  slow_start                    = var.alb_target_group.slow_start
  target_type                   = var.alb_target_group.target_type
  vpc_id                        = var.vpc_id
  connection_termination        = var.alb_target_group.connection_termination
  deregistration_delay          = var.alb_target_group.deregistration_delay
  load_balancing_algorithm_type = var.alb_target_group.load_balancing_algorithm_type

  health_check {
    healthy_threshold   = var.alb_target_group.healthy_threshold
    interval            = var.alb_target_group.interval
    path                = var.alb_target_group.path
    unhealthy_threshold = var.alb_target_group.unhealthy_threshold
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_alb" "contify" {
  count = var.alb_enabled ? 1 : 0

  name                       = var.alb.name
  enable_deletion_protection = var.alb.enable_deletion_protection
  internal                   = var.alb.internal
  load_balancer_type         = var.alb.load_balancer_type
  desync_mitigation_mode     = var.alb.desync_mitigation_mode
  drop_invalid_header_fields = var.alb.drop_invalid_header_fields
  enable_http2               = var.alb.enable_http2
  enable_waf_fail_open       = var.alb.enable_waf_fail_open
  idle_timeout               = var.alb.idle_timeout
  security_groups            = [aws_security_group.contify.id]
  subnets                    = var.alb.subnet_id

  access_logs {
    bucket  = var.alb.logs_bucket
    prefix  = var.alb.logs_prefix
    enabled = true
  }

  tags = var.tags
}

resource "aws_alb_listener" "contify" {
  for_each = try(var.alb_listener, [])

  load_balancer_arn = aws_alb.contify[0].arn
  port              = each.value.port
  protocol          = each.value.protocol
  certificate_arn   = each.value.protocol == "HTTPS" ? try(each.value.certificate_arn, null) : null
  ssl_policy        = each.value.protocol == "HTTPS" ? try(each.value.ssl_policy, null) : null

  default_action {
    type             = each.value.action_type
    target_group_arn = each.value.action_type == "forward" ? aws_alb_target_group.contify[0].arn : null

    dynamic "redirect" {
      for_each = each.value.action_type == "redirect" ? [each.value.redirect] : []

      content {
        status_code = redirect.value.status_code
        port        = redirect.value.port
        protocol    = redirect.value.protocol
      }
    }
  }
}

resource "aws_key_pair" "contify" {
  count = var.key_pair_enabled ? 1 : 0

  key_name   = var.key_pair.key_name
  public_key = file("${path.module}/../../bootstrap/files/envs/${var.env}/id_rsa-contify.pub")

  tags = {
    Env       = var.env
    Terraform = "true"
  }
}

resource "aws_launch_template" "contify" {
  count = var.launch_template.enabled == true ? 1 : 0

  name_prefix = var.launch_template.name_prefix

  image_id               = var.launch_template.image_id
  instance_type          = var.launch_template.instance_type
  key_name               = var.key_pair_enabled ? aws_key_pair.contify[0].key_name : var.key_pair.key_name
  update_default_version = true
  ebs_optimized          = true

  iam_instance_profile {
    name = var.launch_template.iam_instance_profile
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.contify.id]
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = var.launch_template.volume_size
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "contify" {
  count = var.alb_enabled ? 1 : 0

  name_prefix = var.autoscaling_group.name_prefix

  dynamic "launch_template" {
    for_each = var.launch_template.enabled == true ? [1] : []

    content {
      id      = aws_launch_template.contify[0].id
      version = "$Default"
    }
  }

  target_group_arns = [aws_alb_target_group.contify[0].arn]

  min_size                  = var.autoscaling_group.min_size
  max_size                  = var.autoscaling_group.max_size
  desired_capacity          = var.autoscaling_group.desired_capacity
  vpc_zone_identifier       = var.subnet_id
  health_check_type         = var.autoscaling_group.health_check_type
  health_check_grace_period = var.autoscaling_group.health_check_grace_period
  termination_policies      = var.autoscaling_group.termination_policies
  force_delete              = false

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  enabled_metrics = [
    "GroupAndWarmPoolDesiredCapacity",
    "GroupAndWarmPoolTotalCapacity",
    "GroupDesiredCapacity",
    "GroupInServiceCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingCapacity",
    "GroupPendingInstances",
    "GroupStandbyCapacity",
    "GroupStandbyInstances",
    "GroupTerminatingCapacity",
    "GroupTerminatingInstances",
    "GroupTotalCapacity",
    "GroupTotalInstances",
    "WarmPoolDesiredCapacity",
    "WarmPoolMinSize",
    "WarmPoolPendingCapacity",
    "WarmPoolTerminatingCapacity",
    "WarmPoolTotalCapacity",
    "WarmPoolWarmedCapacity"
  ]
}

resource "aws_instance" "contify" {
  count = var.ec2_enabled ? 1 : 0

  ami                         = var.instance.ami
  associate_public_ip_address = false
  availability_zone           = var.aws_availability_zone
  instance_type               = var.instance.instance_type
  key_name                    = var.key_pair_enabled ? aws_key_pair.contify[0].key_name : var.key_pair.key_name
  subnet_id                   = var.instance.subnet_id
  iam_instance_profile        = var.instance.iam_instance_profile
  vpc_security_group_ids      = [aws_security_group.contify.id]

  root_block_device {
    kms_key_id            = var.kms_key_id
    delete_on_termination = true
    encrypted             = true
    volume_size           = 20

    tags = {
      Name      = "contify-${var.env}-${var.aws_region}-root"
      Env       = var.env
      Terraform = "true"
    }
  }

  tags = {
    Name      = "contify-${var.env}-${var.aws_region}"
    Env       = var.env
    Terraform = "true"
  }
}

resource "aws_ebs_volume" "contify_storage" {
  count = var.ec2_enabled ? 1 : 0

  availability_zone = aws_instance.contify[0].availability_zone
  size              = var.contify_storage_ebs.size
  kms_key_id        = var.kms_key_id
  encrypted         = true

  tags = var.contify_storage_ebs.tags
}

resource "aws_volume_attachment" "contify_storage" {
  count = var.ec2_enabled ? 1 : 0

  device_name = "/dev/xvdx"
  volume_id   = aws_ebs_volume.contify_storage[0].id
  instance_id = aws_instance.contify[0].id
}

resource "aws_autoscaling_policy" "contify" {
  for_each = try(var.autoscaling_policy, "")

  enabled                   = true
  name                      = format("contify-%s-%s-%s-policy", var.env, var.aws_region, each.value.name)
  scaling_adjustment        = try(each.value.scaling_adjustment, null)
  cooldown                  = try(each.value.cooldown, null)
  estimated_instance_warmup = try(each.value.estimated_instance_warmup, null)
  autoscaling_group_name    = aws_autoscaling_group.contify[0].name
  min_adjustment_magnitude  = try(each.value.min_adjustment_magnitude, null)
  adjustment_type           = try(each.value.adjustment_type, null)
  policy_type               = try(each.value.policy_type, null)

  dynamic "step_adjustment" {
    for_each = try(each.value.step_adjustment, [])

    content {
      scaling_adjustment          = step_adjustment.value.scaling_adjustment
      metric_interval_lower_bound = try(step_adjustment.value.metric_interval_lower_bound, null)
      metric_interval_upper_bound = try(step_adjustment.value.metric_interval_upper_bound, null)
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "contify" {
  for_each = try(var.autoscaling_policy, "")

  alarm_name          = format("contify-%s-%s-%s-alarm", var.env, var.aws_region, each.value.name)
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  metric_name         = "ActiveConnectionCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = each.value.threshold

  dimensions = {
    LoadBalancer = aws_alb.contify[0].arn_suffix
  }

  alarm_actions = [aws_autoscaling_policy.contify[each.key].arn]
}
