# ==================== envs/test/vars.tf ====================

variable "Project"     { type = string }
variable "Region"      { type = string }
variable "Environment" { type = string }


# VPC
variable "vpc_name"                  { type = string }
variable "vpc_cidr"                  { type = string }
variable "availability_zones_to_use" { type = number }
variable "create_public_subnets"     { type = bool }
variable "create_private_subnets"    { type = bool }
variable "nat_gateway_configuration" { type = string }
variable "enable_https_from_world"   { type = bool }
variable "enable_ssh_from_world"     { type = bool }
variable "ipv6_support"              { type = bool }
variable "force_public_subnet_name"  {
  type = string
  default = null
}
variable "allowed_ingress_cidr"      {
  type = string
  default = null 
}
variable "cluster_name"         { type = string }
variable "service_name"         { type = string }
variable "ecr_repository_name"  { type = string }
variable "desired_count"        {
    type = number
    default = 0
}
variable "image_tag" {
  description = "Tag de la imagen Docker (GitHub SHA por defecto)"
  type        = string
  default     = "latest"
}