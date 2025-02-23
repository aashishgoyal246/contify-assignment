resource "aws_s3_bucket" "contify" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "contify" {
  count = var.versioning_enabled ? 1 : 0

  bucket = aws_s3_bucket.contify.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "contify" {
  count = var.ownership_controls ? 1 : 0

  bucket = aws_s3_bucket.contify.id

  rule {
    object_ownership = var.object_ownership
  }
}

resource "aws_s3_bucket_policy" "contify" {
  count = var.bucket_policy ? 1 : 0

  bucket = aws_s3_bucket.contify.id
  policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {

        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${var.elb_account_id}:root"
        },
        Action   = ["s3:PutObject"]
        Resource = "arn:aws:s3:::${aws_s3_bucket.contify.bucket}/alblogs/*"
      }
    ]
  })
}

resource "aws_s3_bucket_logging" "contify" {
  count = var.bucket_logging ? 1 : 0

  bucket        = aws_s3_bucket.contify.id
  target_bucket = aws_s3_bucket.contify.id
  target_prefix = "s3logs/${aws_s3_bucket.contify.bucket}"
  depends_on    = [aws_s3_bucket.contify]
}

resource "aws_s3_bucket_acl" "contify" {
  count = length(var.bucket_acls)

  acl        = var.bucket_acls[count.index]
  bucket     = aws_s3_bucket.contify.id
  depends_on = [aws_s3_bucket_ownership_controls.contify[0]]
}

resource "aws_s3_bucket_public_access_block" "contify" {
  count = var.bucket_public_access_block ? 1 : 0

  bucket                  = aws_s3_bucket.contify.id
  block_public_acls       = false
  block_public_policy     = true
  ignore_public_acls      = false
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "contify_logs" {
  count = var.bucket_public_access_block_logs ? 1 : 0

  bucket                  = aws_s3_bucket.contify.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
