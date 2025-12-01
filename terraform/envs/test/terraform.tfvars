# ==================== envs/test/terraform.tfvars ====================

Project                     = "prueba-tecnica"
Environment                 = "test"
Region                      = "us-east-1"

# ──────────────── VPC de prueba) ────────────────
vpc_name                    = "api-python-vpc"
vpc_cidr                    = "10.99.0.0/16"

availability_zones_to_use   = 2                     # solo 1 AZ
ipv6_support                = false

# Sin subnets privadas → sin NAT
create_private_subnets      = false
create_public_subnets       = true
nat_gateway_configuration   = "none"

# Seguridad para pruebas rápidas
enable_https_from_world     = true                  # habilitar puerto 443
enable_ssh_from_world       = true                  # solo en test, nunca en prod
allowed_ingress_cidr        = null                  # permite el "from world" de arriba

force_public_subnet_name = "web-app-subnet"

# ──────── ECS Fargate ─────────
cluster_name                = "api-python-cluster"
service_name                = "api-python-service"
ecr_repository_name         = "api-python-repo"
desired_count               = 1
