# ==================== modules/vpc/outputs.tf ====================

output "vpc_id"                    { value = aws_vpc.main.id }
output "vpc_cidr"                  { value = aws_vpc.main.cidr_block }
output "public_subnets"            { value = var.create_public_subnets ? aws_subnet.public[*].id : [] }
output "private_subnets"           { value = var.create_private_subnets ? aws_subnet.private[*].id : [] }
output "nat_gateway_ids"           { value = local.create_nat ? aws_nat_gateway.nat[*].id : [] }
output "internet_gateway_id"       { value = var.create_public_subnets ? aws_internet_gateway.igw[0].id : null }

# OUTPUTS LEGACY EC2
output "public_security_group_id"  { value = aws_security_group.public_sg.id }
output "private_security_group_id" { value = aws_security_group.private_sg.id }

# OUTPUTS ECS FARGATE
output "alb_security_group_id" {
  description = "SG para ALB (ECS Fargate). null si enable_alb_security_group = false"
  value       = var.enable_alb_security_group ? aws_security_group.alb[0].id : null
}
output "ecs_tasks_security_group_id" {
  description = "SG para ECS Tasks. null si enable_ecs_tasks_security_group = false"
  value       = var.enable_ecs_tasks_security_group ? aws_security_group.ecs_tasks[0].id : null
}