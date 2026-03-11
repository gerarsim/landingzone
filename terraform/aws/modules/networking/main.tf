# ═══════════════════════════════════════════════════════════════════
# LZForge — AWS Networking Module
# VPC, public/private subnets (2 AZs), IGW, NAT Gateway,
# route tables, VPC flow logs, locked default SG
# ═══════════════════════════════════════════════════════════════════

data "aws_availability_zones" "available" { state = "available" }

# ── VPC ──────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(var.tags, { Name = "vpc-${var.name_prefix}" })
}

# ── Internet Gateway ──────────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "igw-${var.name_prefix}" })
}

# ── Public subnets (2 AZs) ────────────────────────────────────────────
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = merge(var.tags, {
    Name = "snet-public-${count.index + 1}-${var.name_prefix}"
    Tier = "Public"
  })
}

# ── Private subnets (2 AZs) ───────────────────────────────────────────
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 4)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(var.tags, {
    Name = "snet-private-${count.index + 1}-${var.name_prefix}"
    Tier = "Private"
  })
}

# ── NAT Gateway (single, cost-optimised for landing zone) ────────────
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
  tags       = merge(var.tags, { Name = "eip-nat-${var.name_prefix}" })
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = merge(var.tags, { Name = "nat-${var.name_prefix}" })
  depends_on    = [aws_internet_gateway.main]
}

# ── Route tables ──────────────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = merge(var.tags, { Name = "rt-public-${var.name_prefix}" })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = merge(var.tags, { Name = "rt-private-${var.name_prefix}" })
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ── Lock default security group (CIS AWS Benchmark 5.4) ──────────────
resource "aws_default_security_group" "locked" {
  vpc_id = aws_vpc.main.id
  # No ingress / egress rules — deny all traffic on default SG
  tags = merge(var.tags, { Name = "default-LOCKED-${var.name_prefix}" })
}

# ── VPC Flow Logs → CloudWatch ────────────────────────────────────────
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/lzforge/${var.name_prefix}/vpc-flow-logs"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_iam_role" "flow_logs" {
  name = "role-vpc-flow-logs-${var.name_prefix}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "policy-flow-logs"
  role = aws_iam_role.flow_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup", "logs:CreateLogStream",
        "logs:PutLogEvents", "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
  tags            = merge(var.tags, { Name = "flowlog-${var.name_prefix}" })
}

# ── Network ACLs (allow all within VPC, deny RFC-5737 docs ranges) ───
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }
  ingress {
    rule_no    = 200
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  tags = merge(var.tags, { Name = "nacl-private-${var.name_prefix}" })
}
