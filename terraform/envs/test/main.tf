# ==================== envs/test/main.tf ====================

module "vpc" {
  source = "../../modules/vpc"

  Project                   = var.Project
  vpc_name                  = var.vpc_name
  Environment               = var.Environment
  
  vpc_cidr                  = var.vpc_cidr
  availability_zones_to_use = var.availability_zones_to_use

  nat_gateway_configuration = "none"
  create_private_subnets    = false
  
  # ECS Fargate
  enable_alb_security_group       = true
  enable_ecs_tasks_security_group = true
  ecs_container_port              = 3000

  alb_blocked_cidrs = ["203.0.113.55/32"]   # BLOQUEAR ESTA IP DE PRUEBA
}

module "ecs" {
  source = "../../modules/ecs"

  cluster_name        = var.cluster_name
  service_name        = var.service_name
  ecr_repository_name = var.ecr_repository_name
  desired_count       = var.desired_count
  image_tag           = var.image_tag

  subnets             = module.vpc.public_subnets
  vpc_id              = module.vpc.vpc_id
  alb_sg_id           = module.vpc.alb_security_group_id
  ecs_tasks_sg_id     = module.vpc.ecs_tasks_security_group_id
  aws_region          = var.Region

  alb_blocked_cidrs = ["203.0.113.55/32"]   # BLOQUEAR ESTA IP DE PRUEBA
}
