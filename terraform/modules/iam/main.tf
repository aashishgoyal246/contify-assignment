locals {
  grid = var.grid
}

data "aws_iam_policy_document" "vpc_flow_logs_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "vpc_flow_logs_log_group" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role" "contify_vpc_flow_logs" {
  name               = "${local.grid}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume_role.json
}

resource "aws_iam_role_policy" "contify_vpc_flow_logs" {
  name   = "${local.grid}-vpc-flow-logs"
  role   = aws_iam_role.contify_vpc_flow_logs.id
  policy = data.aws_iam_policy_document.vpc_flow_logs_log_group.json
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com"
      ]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "contify_ec2" {
  name               = "${local.grid}-ec2"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy" "contify_ec2" {
  name = "${local.grid}-ec2"
  role = aws_iam_role.contify_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:DeleteObject",
          "s3:GetBucketAcl",
        ],
        Resource = [
          "arn:aws:s3:::${var.contify_logs_s3_bucket}",
          "arn:aws:s3:::${var.contify_logs_s3_bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth"
        ],
        Resource = [var.alb_target_group_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ],
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Env"  = var.env
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
        ],
        Resource = [
          "arn:aws:kms:${var.aws_region}:${var.account_id}:key/44444b4b-4fd5-4129-a6ce-b9dc5d83c9cd",
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:*",
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "contify_ec2" {
  name = "${local.grid}-ec2"
  role = aws_iam_role.contify_ec2.id
}
