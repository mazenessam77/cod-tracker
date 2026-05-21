output "alb_dns" {
  description = "Hit this URL to access the app"
  value       = aws_lb.main.dns_name
}

output "rds_endpoint" {
  description = "MySQL endpoint for debugging"
  value       = aws_db_instance.mysql.endpoint
}

output "ecr_frontend_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "ecr_backend_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "vpc_id" {
  value = aws_vpc.main.id
}
