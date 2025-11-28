# ==================== modules/vpc/variables.tf ====================

variable "Project"              { type = string }
variable "vpc_name"             { type = string }
variable "Environment"          { type = string }
variable "Region"               { 
    type = string
    default = "us-east-1"
}
variable "vpc_cidr"             { 
    type = string
    default = "10.0.0.0/16"
}
variable "availability_zones_to_use" {
  description = "Número de AZs a usar (1–6)"
  type        = number
  default     = 2
}
variable "ipv6_support" {
  type    = bool
  default = false
}
variable "nat_gateway_configuration" {
  description = "'none' (sin NAT), 'single' (recomendado prod), 'one_per_az' (maxima HA pero caro)"
  type        = string
  default     = "single"
  validation {
    condition     = contains(["none", "single", "one_per_az"], var.nat_gateway_configuration)
    error_message = "Valores permitidos: none, single, one_per_az"
  }
}
variable "create_public_subnets"  {
    type = bool
    default = true
}
variable "create_private_subnets" {
    type = bool
    default = true
}

# Opcional: CIDRs manuales para casos avanzados
variable "public_subnet_cidrs"  {
    type = list(string)
    default = null
}
variable "private_subnet_cidrs" {
    type = list(string)
    default = null
}

# Seguridad: se puede sobreescribir desde fuera
variable "allowed_ingress_cidr" {
  description = "CIDR desde donde permitir acceso (por defecto solo VPC)"
  type        = string
  default     = null
}
variable "enable_ssh_from_world" {
    type = bool
    default = false
}
variable "enable_https_from_world" {
    type = bool
    default = true
}
variable "force_public_subnet_name" {
  description = "Si se define, SOBRESCRIBE el nombre de TODAS las subnets publicas"
  type        = string
  default     = null
}

# VARIABLES ECS FARGATE
variable "enable_alb_security_group" {
  description = "Crea SG específico para ALB (necesario para ECS Fargate). OFF = compatible EC2 tradicional"
  type        = bool
  default     = false
}

variable "enable_ecs_tasks_security_group" {
  description = "Crea SG para ECS Fargate tasks (puerto 5000 desde ALB). OFF = compatible EC2"
  type        = bool
  default     = false
}

variable "alb_ingress_ports" {
  description = "Puertos para ALB (80,443 por defecto para HTTP->HTTPS)"
  type        = list(number)
  default     = [80, 443]
}

variable "ecs_container_port" {
  description = "Puerto del contenedor ECS (5000 por defecto). Util para otras apps"
  type        = number
  default     = 5000
}

# BLOQUEO IP ALB
variable "alb_allowed_cidrs" {
  description = "CIDRs PERMITIDOS en ALB (vacio = todos). Ej: ['192.168.1.0/24']"
  type        = list(string)
  default     = []  # ← VACÍO = 0.0.0.0/0
}

variable "alb_blocked_cidrs" {
  description = "CIDRs BLOQUEADOS en ALB. Ej: ['203.0.113.0/24']"
  type        = list(string)
  default     = []
}