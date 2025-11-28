# ==================== modules/ecs/outputs.tf ====================

output "alb_dns_name" { value = aws_lb.alb.dns_name }
output "alb_ip"       { value = aws_lb.alb.dns_name }
output "cluster_name" { value = aws_ecs_cluster.cluster.name }
output "service_name" { value = aws_ecs_service.service.name }
output "ecr_repository_url" { 
  value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repository_name}"
}
output "https_url"           { value = "https://${aws_lb.alb.dns_name}/health" }
output "task_definition_arn" { value = aws_ecs_task_definition.app.arn }
output "target_group_arn"    { value = aws_lb_target_group.app.arn }
output "https_listener_arn"  { value = aws_lb_listener.https.arn }
output "ecr_repository_name" { value = data.aws_ecr_repository.app.name }
output "service_desired_count" { value = aws_ecs_service.service.desired_count }