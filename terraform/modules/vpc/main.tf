# ==================== modules/vpc/main.tf ====================

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" { state = "available" }

locals {
  selected_azs = slice(data.aws_availability_zones.available.names, 0, var.availability_zones_to_use)
  unique_id   = substr(md5("${var.Region}-${var.Environment}-${data.aws_caller_identity.current.account_id}"), 0, 8)

  public_cidrs  = var.public_subnet_cidrs  != null ? var.public_subnet_cidrs  : [for i in range(var.availability_zones_to_use) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_cidrs = var.private_subnet_cidrs != null ? var.private_subnet_cidrs : [for i in range(var.availability_zones_to_use) : cidrsubnet(var.vpc_cidr, 8, 100 + i)]

  create_nat = var.create_private_subnets && var.nat_gateway_configuration != "none"
  nat_count  = var.nat_gateway_configuration == "one_per_az" ? var.availability_zones_to_use : 1
  ingress_cidr = var.allowed_ingress_cidr != null ? var.allowed_ingress_cidr : var.vpc_cidr
}

# VPC
resource "aws_vpc" "main" {
  cidr_block                       = var.vpc_cidr
  assign_generated_ipv6_cidr_block = var.ipv6_support
  enable_dns_support               = true
  enable_dns_hostnames             = true

  tags = {
    Name        = var.vpc_name
    Environment = var.Environment
  }
}

# SUBNETS PÚBLICAS
resource "aws_subnet" "public" {
  count                   = var.create_public_subnets ? var.availability_zones_to_use : 0
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_cidrs[count.index]
  ipv6_cidr_block         = var.ipv6_support ? cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, count.index) : null
  availability_zone       = local.selected_azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = var.force_public_subnet_name != null ? var.force_public_subnet_name : "public-${element(local.selected_azs, count.index)}"
    Tier = "public"
  }
}

# SUBNETS PRIVADAS
resource "aws_subnet" "private" {
  count             = var.create_private_subnets ? var.availability_zones_to_use : 0
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_cidrs[count.index]
  ipv6_cidr_block   = var.ipv6_support ? cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, 100 + count.index) : null
  availability_zone = local.selected_azs[count.index]

  tags = {
    Name = "private-${element(local.selected_azs, count.index)}"
    Tier = "private"
  }
}

# INTERNET GATEWAY
resource "aws_internet_gateway" "igw" {
  count  = var.create_public_subnets ? 1 : 0
  vpc_id = aws_vpc.main.id
  tags   = { Name = "igw-${var.Project}-${local.unique_id}" }
}

# NAT GATEWAY + EIP
resource "aws_eip" "nat" {
  count  = local.create_nat ? local.nat_count : 0
  domain = "vpc"
  tags   = { Name = "nat-eip-${count.index}" }
}

resource "aws_nat_gateway" "nat" {
  count         = local.create_nat ? local.nat_count : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index % length(aws_subnet.public)].id
  depends_on    = [aws_internet_gateway.igw]
  tags          = { Name = "nat-${var.Project}-${count.index}" }
}

# ROUTE TABLE PÚBLICA
resource "aws_route_table" "public" {
  count  = var.create_public_subnets ? 1 : 0
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw[0].id
  }
  dynamic "route" {
    for_each = var.ipv6_support ? [1] : []
    content {
      ipv6_cidr_block = "::/0"
      gateway_id      = aws_internet_gateway.igw[0].id
    }
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = var.create_public_subnets ? var.availability_zones_to_use : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# ROUTE TABLES PRIVADAS
resource "aws_route_table" "private" {
  count  = var.create_private_subnets ? var.availability_zones_to_use : 0
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = local.create_nat ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.nat_gateway_configuration == "one_per_az" ? aws_nat_gateway.nat[count.index].id : aws_nat_gateway.nat[0].id
    }
  }
  tags = { Name = "private-rt-${element(local.selected_azs, count.index)}" }
}

resource "aws_route_table_association" "private" {
  count          = var.create_private_subnets ? var.availability_zones_to_use : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# SG ALB (HTTP/HTTPS desde internet->ALB)
resource "aws_security_group" "alb" {
  count       = var.enable_alb_security_group ? 1 : 0
  name        = "alb-sg-${local.unique_id}"
  description = "ALB para ECS Fargate"
  vpc_id      = aws_vpc.main.id

  # PERMITIDO EXPLÍCITO
  dynamic "ingress" {
    for_each = toset([for port in var.alb_ingress_ports : port])
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = length(var.alb_allowed_cidrs) > 0 ? var.alb_allowed_cidrs : ["0.0.0.0/0"]
      description = "ALB ${ingress.value}"
    }
  }

  # BLOQUEO EXPLÍCITO
  dynamic "ingress" {
    for_each = var.alb_blocked_cidrs
    content {
      from_port   = 0
      to_port     = 65535
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "BLOCKED: ${ingress.value}"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
    Environment = var.Environment
  }
}

# SG ECS TASKS (ALB->contenedor puerto 5000)
resource "aws_security_group" "ecs_tasks" {
  count       = var.enable_ecs_tasks_security_group ? 1 : 0
  name        = "ecs-tasks-sg-${local.unique_id}"
  description = "ECS Fargate tasks (ALB to container ${var.ecs_container_port})"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = var.ecs_container_port
    to_port         = var.ecs_container_port
    protocol        = "tcp"
    security_groups = var.enable_alb_security_group ? [aws_security_group.alb[0].id] : []
    description     = "ALB to ECS Task ${var.ecs_container_port}"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Internet outbound"
  }

  tags = {
    Name = "ecs-tasks-sg"
    Environment = var.Environment
  }
}

# SECURITY GROUPS (EC2 TRADICIONAL)
resource "aws_security_group" "public_sg" {
  name        = "public-sg-${local.unique_id}"
  description = "SG publico controlado (EC2 tradicional)"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.enable_https_from_world ? [443] : []
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  dynamic "ingress" {
    for_each = var.enable_ssh_from_world ? [22] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.ingress_cidr]
    description = "Todo el trafico desde dentro de la VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "public-sg" }
}

resource "aws_security_group" "private_sg" {
  name        = "private-sg-${local.unique_id}"
  vpc_id      = aws_vpc.main.id
  description = "Solo salida para subnets privadas"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "private-sg" }
}