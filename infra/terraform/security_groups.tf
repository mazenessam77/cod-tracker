# Security groups for ALB, ECS tasks, and RDS

# ALB — accepts HTTP/HTTPS from the internet
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB inbound rules"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-sg" }
}

# Frontend ECS tasks — only ALB can reach them on port 80
resource "aws_security_group" "frontend" {
  name        = "${var.project_name}-frontend-sg"
  description = "Frontend ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "From ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-frontend-sg" }
}

# Backend ECS tasks — only frontend tasks can reach them on port 5000
resource "aws_security_group" "backend" {
  name        = "${var.project_name}-backend-sg"
  description = "Backend ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "From frontend"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-backend-sg" }
}

# RDS — only backend tasks can reach it on 3306
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS MySQL access"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from backend"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-rds-sg" }
}
