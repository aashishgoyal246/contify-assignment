resource "aws_vpc" "contify" {
  cidr_block           = var.cidr_block
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "contify" {
  name_prefix = var.log_group_prefix

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_flow_log" "contify" {
  iam_role_arn    = var.vpc_log_iam_role_arn
  log_destination = aws_cloudwatch_log_group.contify.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.contify.id

  tags = var.tags
}

resource "aws_internet_gateway" "contify" {
  vpc_id = aws_vpc.contify.id

  tags = var.tags
}

resource "aws_route_table" "contify" {
  vpc_id = aws_vpc.contify.id

  tags = merge(
    var.tags,
    {
      Name = "${var.subnet_tag}-public"
    }
  )
}

resource "aws_route" "contify_internet" {
  route_table_id         = aws_route_table.contify.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.contify.id
}

resource "aws_subnet" "contify" {
  count = length(var.aws_availability_zones)

  vpc_id                  = aws_vpc.contify.id
  availability_zone       = element(var.aws_availability_zones, count.index)
  map_public_ip_on_launch = true
  cidr_block              = cidrsubnet(var.cidr_block, 8, count.index)

  tags = merge(
    var.tags,
    var.public_subnet_tags,
    {
      Name = "${var.subnet_tag}-public-${count.index}"
    }
  )
}

resource "aws_route_table_association" "contify" {
  count = length(aws_subnet.contify.*.id)

  subnet_id      = element(aws_subnet.contify.*.id, count.index)
  route_table_id = aws_route_table.contify.id
}

resource "aws_eip" "contify_private" {
  count = var.private_subnet_enabled ? 1 : 0

  domain = "vpc"

  tags = var.tags
}

resource "aws_nat_gateway" "contify_private" {
  count = var.private_subnet_enabled ? 1 : 0

  allocation_id = aws_eip.contify_private[count.index].id
  subnet_id     = aws_subnet.contify[count.index].id

  tags = var.tags

  depends_on = [
    aws_internet_gateway.contify
  ]
}

resource "aws_route_table" "contify_private" {
  count = var.private_subnet_enabled ? 1 : 0

  vpc_id = aws_vpc.contify.id

  tags = merge(
    var.tags,
    {
      Name = "${var.subnet_tag}-private"
    }
  )
}

resource "aws_route" "contify_private" {
  count = var.private_subnet_enabled ? 1 : 0

  route_table_id         = aws_route_table.contify_private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.contify_private[count.index].id
}

resource "aws_subnet" "contify_private" {
  count = var.private_subnet_enabled ? length(var.aws_availability_zones) : 0

  vpc_id            = aws_vpc.contify.id
  availability_zone = element(var.aws_availability_zones, count.index)
  cidr_block        = cidrsubnet(var.cidr_block, 4, count.index + 1)

  tags = merge(
    var.tags,
    var.private_subnet_tags,
    {
      Name = "${var.subnet_tag}-private-${count.index}"
    }
  )

  depends_on = [aws_subnet.contify]
}

resource "aws_route_table_association" "contify_private" {
  count = var.private_subnet_enabled ? length(aws_subnet.contify_private.*.id) : 0

  subnet_id      = element(aws_subnet.contify_private.*.id, count.index)
  route_table_id = aws_route_table.contify_private[0].id
}
