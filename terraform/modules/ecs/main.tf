# ==================== modules/ecs/main.tf ====================

data "aws_caller_identity" "current" {}

# ECR Repository
# The repository is managed externally (existing ECR). Use a data source to
# reference it instead of creating/destroying it with Terraform. This prevents
# Terraform from attempting to delete a repository that wasn't created here.
data "aws_ecr_repository" "app" {
  name = var.ecr_repository_name
}

# Lifecycle policy: target the existing repository by name. Using the variable
# ensures we don't depend on a resource that Terraform would try to destroy.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = var.ecr_repository_name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}

# ECS Cluster (SIN capacity_providers)
resource "aws_ecs_cluster" "cluster" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# CAPACITY PROVIDERS (RECURSO SEPARADO)
resource "aws_ecs_cluster_capacity_providers" "cluster_providers" {
  cluster_name = aws_ecs_cluster.cluster.name

  capacity_providers = ["FARGATE_SPOT", "FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
    base              = 0
  }

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 0
    base              = 1
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.service_name}"
  retention_in_days = 7
}

# ECS Execution Role
resource "aws_iam_role" "ecs_execution" {
  name = "ecs-execution-${var.service_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "app"
    image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repository_name}:${var.image_tag}"
    essential = true
    portMappings = [{ containerPort = var.container_port }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.service_name}"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
    environment = [
      { name = "DB_HOST", value = "localhost" },
      { name = "DB_USER", value = "root" },
      { name = "DB_PASS", value = "password" },
      { name = "DB_NAME", value = "testdb" }
    ]
  }])

  depends_on = [aws_cloudwatch_log_group.app]
}

# ALB
resource "aws_lb" "alb" {
  name                             = "app-alb-${var.service_name}"
  internal                         = false
  load_balancer_type               = "application"
  security_groups                  = [var.alb_sg_id]
  subnets                          = var.subnets
  enable_deletion_protection       = true
  enable_cross_zone_load_balancing = true

  tags = { Name = "PoC-ALB-IP-HTTPS" }
}

# Target Group
resource "aws_lb_target_group" "app" {
  name     = "app-tg-${var.service_name}"
  port     = var.container_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "ip"  # FARGATE awsvpc

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
}

# CERTIFICADO SELF-SIGNED
resource "tls_private_key" "alb_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "alb_cert" {
  private_key_pem = tls_private_key.alb_key.private_key_pem

  subject {
    common_name  = aws_lb.alb.dns_name
    organization = "PoC DevOps 2025"
  }

  validity_period_hours = 8760  # 1 año

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "self_signed" {
  private_key         = tls_private_key.alb_key.private_key_pem
  certificate_body    = tls_self_signed_cert.alb_cert.cert_pem
  certificate_chain   = tls_self_signed_cert.alb_cert.cert_pem

  lifecycle {
    create_before_destroy = true
  }
}

# Listener HTTPS
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.self_signed.arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# HTTP -> HTTPS Redirect
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ECS Service (SIN autoscaling_policy)
resource "aws_ecs_service" "service" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count

  launch_type = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    assign_public_ip = true
    security_groups  = [var.ecs_tasks_sg_id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  depends_on = [
    aws_ecs_cluster_capacity_providers.cluster_providers,
    aws_lb_listener.https
  ]
}

# AUTOSCALING (RECURSOS SEPARADOS)
resource "aws_appautoscaling_target" "ecs_service" {
  count              = var.desired_count > 0 ? 1 : 0
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu_scaling" {
  count              = var.desired_count > 0 ? 1 : 0
  name               = "scale-on-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "memory_scaling" {
  count              = var.desired_count > 0 ? 1 : 0
  name               = "scale-on-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 80.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}