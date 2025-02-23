resource "random_string" "contify_database_username" {
  length  = 20
  special = false
}

resource "random_string" "contify_database_password" {
  length  = 20
  special = false
}

resource "random_string" "contify_database_name" {
  length  = 20
  special = false
}

resource "aws_db_subnet_group" "contify" {
  name       = var.db_subnet_group.name
  subnet_ids = var.db_subnet_group.subnet_ids
}

resource "aws_rds_cluster_parameter_group" "contify" {
  name   = var.rds_cluster_parameter_group.name
  family = var.rds_cluster_parameter_group.family

  dynamic "parameter" {
    for_each = var.rds_cluster_parameter_group.parameter

    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }
}

resource "aws_rds_cluster" "contify" {
  cluster_identifier              = var.rds_cluster.cluster_identifier
  db_subnet_group_name            = aws_db_subnet_group.contify.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.contify.name
  vpc_security_group_ids          = [var.rds_cluster.vpc_security_group_ids]
  engine                          = "aurora-postgresql"
  engine_version                  = var.rds_cluster.engine_version
  database_name                   = var.database_name
  master_username                 = var.database_username
  master_password                 = var.database_password
  backup_retention_period         = var.rds_cluster.backup_retention_period
  storage_encrypted               = true
  kms_key_id                      = var.rds_cluster.kms_key_id
  skip_final_snapshot             = true
  copy_tags_to_snapshot           = true
  apply_immediately               = true
  snapshot_identifier             = try(var.rds_cluster.snapshot_identifier, null)
  enabled_cloudwatch_logs_exports = ["postgresql"]

  dynamic "serverlessv2_scaling_configuration" {
    for_each = try(var.serverless, [])

    content {
      min_capacity = serverlessv2_scaling_configuration.value.min_capacity
      max_capacity = serverlessv2_scaling_configuration.value.max_capacity
    }
  }

  lifecycle {
    ignore_changes = [
      database_name,
      master_username,
      master_password
    ]
  }

  tags = {
    Name      = var.rds_cluster.cluster_identifier
    Env       = var.env
    Terraform = "true"
  }
}

## DB Cluster Instance
resource "aws_rds_cluster_instance" "contify" {
  count = var.database_instance_count

  identifier                            = "${aws_rds_cluster.contify.cluster_identifier}-${format("%02d", count.index)}"
  db_subnet_group_name                  = aws_db_subnet_group.contify.name
  cluster_identifier                    = aws_rds_cluster.contify.id
  instance_class                        = var.database_instance_class
  engine                                = aws_rds_cluster.contify.engine
  engine_version                        = aws_rds_cluster.contify.engine_version
  publicly_accessible                   = false
  copy_tags_to_snapshot                 = true
  apply_immediately                     = true
  promotion_tier                        = 0
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  tags = {
    Name            = "${aws_rds_cluster.contify.cluster_identifier}-${format("%02d", count.index)}"
    Env             = var.env
    Terraform       = "true"
    DevOps-Guru-RDS = "${aws_rds_cluster.contify.cluster_identifier}-${format("%02d", count.index)}"
  }
}

resource "aws_rds_cluster_instance" "contify_secondary" {
  count = var.database_secondary_instance_count

  identifier                            = "${aws_rds_cluster.contify.cluster_identifier}-secondary-${format("%02d", count.index)}"
  db_subnet_group_name                  = aws_db_subnet_group.contify.name
  cluster_identifier                    = aws_rds_cluster.contify.id
  instance_class                        = var.database_secondary_instance_class
  engine                                = aws_rds_cluster.contify.engine
  engine_version                        = aws_rds_cluster.contify.engine_version
  publicly_accessible                   = false
  copy_tags_to_snapshot                 = true
  apply_immediately                     = true
  promotion_tier                        = 1
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  tags = {
    Name            = "${aws_rds_cluster.contify.cluster_identifier}-secondary-${format("%02d", count.index)}"
    Env             = var.env
    Terraform       = "true"
    DevOps-Guru-RDS = "${aws_rds_cluster.contify.cluster_identifier}-secondary-${format("%02d", count.index)}"
  }

  depends_on = [aws_rds_cluster_instance.contify]
}

# RDS Reader Scaling
resource "aws_appautoscaling_target" "contify" {
  count = var.rds_autoscaling.enabled ? 1 : 0

  service_namespace  = "rds"
  scalable_dimension = "rds:cluster:ReadReplicaCount"
  resource_id        = "cluster:${aws_rds_cluster.contify.cluster_identifier}"
  min_capacity       = var.rds_autoscaling.min_capacity
  max_capacity       = var.rds_autoscaling.max_capacity

  tags = {
    Name      = "${aws_rds_cluster.contify.cluster_identifier}-autoscaling-${format("%02d", count.index)}"
    Env       = var.env
    Terraform = "true"
  }
}

resource "aws_appautoscaling_policy" "contify" {
  for_each = try(var.rds_autoscaling.policy, {})

  name               = each.key
  policy_type        = "TargetTrackingScaling"
  resource_id        = "cluster:${aws_rds_cluster.contify.cluster_identifier}"
  scalable_dimension = "rds:cluster:ReadReplicaCount"
  service_namespace  = "rds"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = each.value.predefined_metric_type
    }

    target_value       = each.value.target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }

  depends_on = [
    aws_appautoscaling_target.contify
  ]
}
