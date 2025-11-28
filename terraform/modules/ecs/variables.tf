# ==================== modules/ecs/variables.tf ====================

variable "cluster_name"         { type = string }
variable "service_name"         { type = string }
variable "ecr_repository_name"  { type = string }
variable "desired_count"        {
    type = number
    default = 0
}
variable "subnets"              { type = list(string) }
variable "vpc_id"               { type = string }
variable "aws_region"           { type = string }
variable "alb_sg_id"            { type = string }
variable "ecs_tasks_sg_id"      { type = string }
variable "container_port"       {
    type = number
    default = 3000
}
variable "image_tag" {
    type = string
    default = "latest"
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