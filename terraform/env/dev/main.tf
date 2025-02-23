locals {
  grid = "contify-${var.env}-${var.region}"
}

data "aws_kms_key" "contify" {
  key_id = "alias/${var.contify_kms_key_alias}"
}

module "contify_logs_s3" {
  source = "../../modules/s3"

  bucket_name = "contify-logs-${var.env}-${var.region}"

  versioning_enabled              = true
  ownership_controls              = true
  object_ownership                = "BucketOwnerPreferred"
  bucket_policy                   = true
  bucket_logging                  = true
  bucket_public_access_block      = false
  bucket_public_access_block_logs = true

  elb_account_id = var.elb_account_id

  bucket_acls = ["log-delivery-write", "private"]

  tags = {
    Env       = var.env
    Terraform = "true"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  subnet_tag = local.grid

  private_subnet_enabled = true

  log_group_prefix       = "${local.grid}-"
  vpc_log_iam_role_arn   = module.iam.vpc_log_iam_role_arn
  aws_availability_zones = var.aws_availability_zones

  tags = {
    Name      = "${local.grid}"
    Env       = var.env
    Terraform = "true"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = "${local.grid}"
    "Tier"                            = "Private"
  }
}

module "iam" {
  source = "../../modules/iam"

  grid       = local.grid
  env        = var.env
  aws_region = var.region

  contify_logs_s3_bucket = module.contify_logs_s3.s3_bucket_name

  alb_target_group_arn = module.ec2.alb_target_group_arn
}

module "ec2" {
  source = "../../modules/ec2"

  vpc_id      = module.vpc.vpc_id
  vpc_sg_name = local.grid

  env        = var.env
  aws_region = var.region

  kms_key_id = data.aws_kms_key.contify.arn

  subnet_id             = module.vpc.subnet_id
  aws_availability_zone = var.aws_availability_zones[0]

  ingress_rule = {
    contify_self_ingress = {
      description = "Allow all inbound traffic originating from resources in this security group"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      self        = true
    },
    contify_self_cidr = {
      description = "Allow all inbound traffic originating from self cidr in this security group"
      cidr_blocks = ["10.3.0.0/16"]
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
    },
    contify_http_ingress = {
      description = "Allow all inbound HTTP traffic"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
    },
    contify_https_ingress = {
      description = "Allow all inbound HTTPS traffic"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
    },
    contify_ssh_ingress = {
      description = "Allow inbound SSH traffic"
      cidr_blocks = var.allowed_ssh_ips
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
    }
  }

  egress_rule = {
    contify_egress = {
      description = "Allow all outbound traffic"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
    }
  }

  alb_enabled = true

  alb_target_group = {
    name                          = local.grid
    port                          = 80
    protocol                      = "HTTP"
    proxy_protocol_v2             = false
    slow_start                    = 0
    target_type                   = "instance"
    vpc_id                        = module.vpc.vpc_id
    connection_termination        = false
    deregistration_delay          = 1800
    load_balancing_algorithm_type = "least_outstanding_requests"

    healthy_threshold   = 2
    interval            = 30
    path                = "/health"
    unhealthy_threshold = 2
  }

  alb = {
    name                       = local.grid
    enable_deletion_protection = false
    internal                   = false
    load_balancer_type         = "application"
    desync_mitigation_mode     = "defensive"
    drop_invalid_header_fields = true
    enable_http2               = true
    enable_waf_fail_open       = false
    idle_timeout               = 60

    subnet_id = module.vpc.subnet_id

    logs_bucket = module.contify_logs_s3.s3_bucket_name
    logs_prefix = "alblogs/${local.grid}"
  }

  alb_listener = {
    contify_http = {
      port        = "80"
      protocol    = "HTTP"
      action_type = "redirect"

      redirect = {
        status_code = "HTTP_301"
        port        = "443"
        protocol    = "HTTPS"
      }
    },
    contify_https = {
      port            = "443"
      protocol        = "HTTPS"
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
      certificate_arn = var.certificate_arn
      action_type     = "forward"
    }
  }

  key_pair_enabled = true

  key_pair = {
    key_name = local.grid
  }

  launch_template = {
    enabled              = true
    name_prefix          = "${local.grid}-"
    image_id             = var.contify_ami
    instance_type        = var.contify_instance_type
    iam_instance_profile = module.iam.ec2_iam_instance_profile_id
    volume_size          = 200
  }

  autoscaling_group = {
    name_prefix               = "${local.grid}-"
    min_size                  = var.contify_autoscaling_min_count
    max_size                  = var.contify_autoscaling_max_count
    desired_capacity          = var.contify_autoscaling_desired_count
    health_check_type         = "ELB"
    health_check_grace_period = 3600
    termination_policies      = ["NewestInstance"]
  }

  autoscaling_policy = {
    scale-in = {
      name                     = "scale-in"
      scaling_adjustment       = -1
      cooldown                 = 600
      policy_type              = "SimpleScaling"
      comparison_operator      = "LessThanOrEqualToThreshold"
      adjustment_type          = "PercentChangeInCapacity"
      min_adjustment_magnitude = 1
      threshold                = 100000
    },

    scale-out = {
      name                      = "scale-out"
      policy_type               = "StepScaling"
      estimated_instance_warmup = 300
      adjustment_type           = "ExactCapacity"
      comparison_operator       = "GreaterThanOrEqualToThreshold"
      threshold                 = 100000

      step_adjustment = [
        {
          scaling_adjustment          = 2
          metric_interval_lower_bound = 0
          metric_interval_upper_bound = 150000
        },
        {
          scaling_adjustment          = 3
          metric_interval_lower_bound = 150000
        }
      ]
    }
  }

  instance = {
    ami                  = var.contify_ami
    instance_type        = var.contify_instance_type
    iam_instance_profile = module.iam.ec2_iam_instance_profile_id
    subnet_id            = module.vpc.subnet_id[0]
  }

  contify_storage_ebs = {
    size = var.contify_ebs_size

    tags = {
      Name = "${local.grid}-storage"
      Env  = var.env
    }
  }

  tags = {
    Name      = "${local.grid}"
    Env       = var.env
    Terraform = "true"
  }
}

module "rds" {
  source = "../../modules/rds"

  db_subnet_group = {
    name       = local.grid
    subnet_ids = module.vpc.subnet_id
  }

  rds_cluster_parameter_group = {
    name      = format("%s-16-4", local.grid)
    family    = var.rds_cluster_parameter_group.family
    parameter = var.rds_cluster_parameter_group.parameter
  }

  env = var.env

  rds_cluster = {
    cluster_identifier      = local.grid
    engine_version          = "16.4"
    backup_retention_period = 7
    kms_key_id              = data.aws_kms_key.contify.arn
    vpc_security_group_ids  = module.ec2.contify_security_group_id
  }

  rds_autoscaling = {
    enabled      = true
    min_capacity = 1
    max_capacity = 3

    policy = {
      average_cpu = {
        predefined_metric_type = "RDSReaderAverageCPUUtilization"
        target_value           = 70
      },

      average_connections = {
        predefined_metric_type = "RDSReaderAverageDatabaseConnections"
        target_value           = 2500
      }
    }
  }

  database_name                     = var.database_name
  database_username                 = var.database_username
  database_password                 = var.database_password
  database_instance_count           = var.database_instance_count
  database_instance_class           = var.database_instance_class
  database_secondary_instance_count = var.database_secondary_instance_count
  database_secondary_instance_class = var.database_secondary_instance_class
}

module "ec2_db" {
  source = "../../modules/ec2"

  vpc_id      = module.vpc.vpc_id
  vpc_sg_name = "${local.grid}-db"

  env        = var.env
  aws_region = var.region

  kms_key_id = data.aws_kms_key.contify.arn

  subnet_id             = module.vpc.private_subnet_id
  aws_availability_zone = var.aws_availability_zones[1]

  ingress_rule = {
    contify_self_ingress = {
      description = "Allow all inbound traffic originating from resources in this security group"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      self        = true
    },
    contify_self_cidr = {
      description = "Allow all inbound traffic originating from self cidr in this security group"
      cidr_blocks = ["10.3.0.0/16"]
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
    },
    contify_app_ingress = {
      description              = "Allow inbound traffic from app"
      source_security_group_id = module.ec2.contify_security_group_id
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
    },
    contify_ssh_ingress = {
      description = "Allow inbound SSH traffic"
      cidr_blocks = var.allowed_ssh_ips
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
    }
  }

  egress_rule = {
    contify_egress = {
      description = "Allow all outbound traffic"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
    }
  }

  alb_enabled = false

  key_pair_enabled = false

  key_pair = {
    key_name = local.grid
  }

  launch_template = {
    enabled              = true
    name_prefix          = "${local.grid}-db-"
    image_id             = var.contify_ami
    instance_type        = var.contify_instance_type
    iam_instance_profile = module.iam.ec2_iam_instance_profile_id
    volume_size          = 200
  }

  instance = {
    ami                  = var.contify_ami
    instance_type        = var.contify_instance_type
    iam_instance_profile = module.iam.ec2_iam_instance_profile_id
    subnet_id            = module.vpc.private_subnet_id[1]
  }

  contify_storage_ebs = {
    size = var.contify_ebs_size

    tags = {
      Name = "${local.grid}-db-storage"
      Env  = var.env
    }
  }

  tags = {
    Name      = "${local.grid}-db"
    Env       = var.env
    Terraform = "true"
  }
}

module "ec2_cicd" {
  source = "../../modules/ec2"

  vpc_id      = module.vpc.vpc_id
  vpc_sg_name = "${local.grid}-cicd-"

  env        = var.env
  aws_region = var.region

  kms_key_id = data.aws_kms_key.contify.arn

  subnet_id             = module.vpc.private_subnet_id
  aws_availability_zone = var.aws_availability_zones[2]

  ingress_rule = {
    contify_self_ingress = {
      description = "Allow all inbound traffic originating from resources in this security group"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      self        = true
    },
    contify_self_cidr = {
      description = "Allow all inbound traffic originating from self cidr in this security group"
      cidr_blocks = ["10.3.0.0/16"]
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
    }
    contify_ssh_ingress = {
      description = "Allow inbound SSH traffic"
      cidr_blocks = var.allowed_ssh_ips
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
    }
  }

  egress_rule = {
    contify_egress = {
      description = "Allow all outbound traffic"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
    }
  }

  alb_enabled = false

  key_pair_enabled = false

  key_pair = {
    key_name = local.grid
  }

  launch_template = {
    enabled              = true
    name_prefix          = "${local.grid}-cicd-"
    image_id             = var.contify_ami
    instance_type        = var.contify_instance_type
    iam_instance_profile = module.iam.ec2_iam_instance_profile_id
    volume_size          = 200
  }

  instance = {
    ami                  = var.contify_ami
    instance_type        = var.contify_instance_type
    iam_instance_profile = module.iam.ec2_iam_instance_profile_id
    subnet_id            = module.vpc.private_subnet_id[2]
  }

  contify_storage_ebs = {
    size = var.contify_ebs_size

    tags = {
      Name = "${local.grid}-cicd-storage"
      Env  = var.env
    }
  }

  tags = {
    Name      = "${local.grid}-cicd"
    Env       = var.env
    Terraform = "true"
  }
}

module "cloudwatch_ec2" {
  source = "../../modules/cloudwatch"

  env        = var.env
  aws_region = var.region

  alarm_policy = {
    ec2_high_cpu = {
      name                = "ec2-high-cpu"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      metric_name         = "CPUUtilization"
      namespace           = "AWS/EC2"
      statistic           = "Average"
      threshold           = "75"
      alarm_actions       = [var.sns_topic_arn]

      dimensions = {
        InstanceId = module.ec2_db.instance_id
      }
    },

    ec2_status_check = {
      name                = "ec2-status-check"
      comparison_operator = "GreaterThanThreshold"
      metric_name         = "StatusCheckFailed"
      namespace           = "AWS/EC2"
      statistic           = "Maximum"
      threshold           = "0"
      alarm_actions       = [var.sns_topic_arn]

      dimensions = {
        InstanceId = module.ec2_db.instance_id
      }
    }
  }
}

module "cloudwatch_rds" {
  source = "../../modules/cloudwatch"

  env        = var.env
  aws_region = var.region

  alarm_policy = {
    rds_high_cpu = {
      name                = "rds-high-cpu"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      metric_name         = "CPUUtilization"
      namespace           = "AWS/RDS"
      statistic           = "Average"
      threshold           = "75"
      alarm_actions       = [var.sns_topic_arn]

      dimensions = {
        DBClusterIdentifier = module.rds.rds_cluster_id
        Role                = "WRITER"
      }
    },

    rds_high_db_connections = {
      name                = "rds-high-db-connections"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      metric_name         = "DatabaseConnections"
      namespace           = "AWS/RDS"
      statistic           = "Maximum"
      threshold           = "2500"
      alarm_actions       = [var.sns_topic_arn]

      dimensions = {
        DBClusterIdentifier = module.rds.rds_cluster_id
        Role                = "WRITER"
      }
    }
  }
}
