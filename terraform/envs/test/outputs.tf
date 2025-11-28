# ==================== envs/test/outputs.tf ====================

# ────────────── VPC & NETWORK INFO ──────────────
output "vpc_info" {
  description = "Informacion completa de la VPC y red"
  value = {
    vpc_id                    = module.vpc.vpc_id
    vpc_cidr                  = module.vpc.vpc_cidr
    public_subnets            = module.vpc.public_subnets
    private_subnets           = module.vpc.private_subnets
    internet_gateway_id       = module.vpc.internet_gateway_id
    nat_gateway_ids           = module.vpc.nat_gateway_ids
    
    # ECS FARGATE Security Groups
    alb_security_group_id     = module.vpc.alb_security_group_id
    ecs_tasks_security_group_id = module.vpc.ecs_tasks_security_group_id
    
    # Legacy EC2 Security Groups
    public_security_group_id  = module.vpc.public_security_group_id
    private_security_group_id = module.vpc.private_security_group_id
  }
}

# ────────────── ECS FARGATE INFO ──────────────
output "ecs_info" {
  description = "Informacion completa de ECS Fargate"
  value = {
    cluster_name     = module.ecs.cluster_name
    service_name     = module.ecs.service_name
    task_definition  = module.ecs.task_definition_arn
    desired_count    = module.ecs.service_desired_count
    
    # ECR Repository
    ecr_repository_url = module.ecs.ecr_repository_url
    
    # URLs de Acceso
    https_url        = module.ecs.https_url
    alb_dns_name     = module.ecs.alb_dns_name
    alb_ip           = module.ecs.alb_ip

    task_definition  = module.ecs.task_definition_arn
    target_group_arn = module.ecs.target_group_arn
  }
}

# ────────────── ALB & LOAD BALANCER ──────────────
output "alb_info" {
  description = "Informacion del Application Load Balancer"
  value = {
    alb_dns_name     = module.ecs.alb_dns_name
    alb_ip           = module.ecs.alb_ip
    target_group_arn = module.ecs.target_group_arn
    https_listener_arn = module.ecs.https_listener_arn
    https_url        = module.ecs.https_url
  }
}

# ────────────── ECR INFO ──────────────
output "ecr_info" {
  description = "Informacion del repositorio ECR"
  value = {
    repository_url     = module.ecs.ecr_repository_url
    repository_name    = module.ecs.ecr_repository_name
    image_latest_tag   = "${module.ecs.ecr_repository_url}:latest"
    image_sha_tag      = "${module.ecs.ecr_repository_url}:${var.image_tag}"
  }
}

# ────────────── QUICK ACCESS (URLs listas para usar) ──────────────
output "quick_access_urls" {
  description = "URLs listas"
  value = {
    health_check  = module.ecs.https_url
    api_root      = "${module.ecs.https_url}/"
    alb_direct    = "https://${module.ecs.alb_dns_name}/"
    curl_command  = "curl -k '${module.ecs.https_url}/health'"
  }
}

# ────────────── SUMMARY (Para GitHub Actions/Consola) ──────────────
output "deployment_summary" {
  description = "Resumen completo del deploy"
  value = {
    project         = var.Project
    environment     = var.Environment
    region          = var.Region
    vpc_id          = module.vpc.vpc_id
    cluster         = module.ecs.cluster_name
    service         = module.ecs.service_name
    status          = "🚀 DEPLOYED"
    https_url       = module.ecs.https_url
    ecr_url         = module.ecs.ecr_repository_url
  }
}

# ────────────── LEGACY OUTPUTS (Para scripts antiguos) ──────────────
output "vpc_id" { value = module.vpc.vpc_id }
output "public_subnets" { value = module.vpc.public_subnets }
output "https_url" { value = module.ecs.https_url }
output "alb_dns" { value = module.ecs.alb_dns_name }
