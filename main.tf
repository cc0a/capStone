terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  vpc_cidr_block = "10.0.0.0/16"
  newbits        = 2
}

# -----------------
# VPC
# -----------------
resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "wordpress-vpc" }
}

# -----------------
# Subnets
# -----------------
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(local.vpc_cidr_block, local.newbits, 0)
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                     = { Name = "public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(local.vpc_cidr_block, local.newbits, 1)
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags                     = { Name = "public-b" }
}

resource "aws_subnet" "private_app" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidr_block, local.newbits, 2)
  availability_zone = "us-east-1c"
  tags               = { Name = "private-app" }
}

resource "aws_subnet" "private_rds" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidr_block, local.newbits, 3)
  availability_zone = "us-east-1d"
  tags               = { Name = "private-rds" }
}

# -----------------
# Internet Gateway + Route Tables
# -----------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "main-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public_a_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b_assoc" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# -----------------
# Security Groups
# -----------------
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-wordpress-sg"
  description = "Allow inbound HTTP/HTTPS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
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
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow MySQL only from ECS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------
# RDS Subnet Group + Instance
# -----------------
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "wordpress-rds-subnet-group"
  subnet_ids = [aws_subnet.private_rds.id]

  tags = { Name = "wordpress-rds-subnet-group" }
}

resource "aws_db_instance" "wordpress_db" {
  identifier              = "wordpress-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "wordpress"
  username                = "admin"
  password                = "changeme123!" # Replace in production
  skip_final_snapshot     = true
  publicly_accessible     = false

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name

  tags = { Name = "wordpress-db" }
}

# -----------------
# ECS Cluster
# -----------------
resource "aws_ecs_cluster" "wp_cluster" {
  name = "wordpress-cluster"
}

# -----------------
# ECR Repository for hardened WordPress image
# -----------------
resource "aws_ecr_repository" "wp_repo" {
  name = "wordpress-hardened"
}

# -----------------
# Load Balancer (ALB)
# -----------------
resource "aws_lb" "wp_alb" {
  name               = "wordpress-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_lb_target_group" "wp_tg" {
  name     = "wp-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check { path = "/" }
}

resource "aws_lb_listener" "wp_listener" {
  load_balancer_arn = aws_lb.wp_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wp_tg.arn
  }
}

# -----------------
# ECS Task Execution Role
# -----------------
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# -----------------
# EFS for wp-content
# -----------------
resource "aws_efs_file_system" "wp_content" {
  creation_token = "wordpress-wp-content"
  encrypted      = true
}

resource "aws_efs_mount_target" "wp_content_a" {
  file_system_id  = aws_efs_file_system.wp_content.id
  subnet_id       = aws_subnet.private_app.id
  security_groups = [aws_security_group.ecs_sg.id]
}

resource "aws_efs_mount_target" "wp_content_b" {
  file_system_id  = aws_efs_file_system.wp_content.id
  subnet_id       = aws_subnet.private_rds.id
  security_groups = [aws_security_group.ecs_sg.id]
}

# -----------------
# ECS Task Definition (Hardened)
# -----------------
resource "aws_ecs_task_definition" "wp_task" {
  family                   = "wordpress-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  volume {
    name = "wp-content"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.wp_content.id
      root_directory = "/"
    }
  }

  container_definitions = jsonencode([
    {
      name      = "wordpress"
      image     = "${aws_ecr_repository.wp_repo.repository_url}:latest"
      essential = true

      portMappings = [{ containerPort = 80, protocol = "tcp" }]

      environment = [
        { name = "WORDPRESS_DB_HOST", value = aws_db_instance.wordpress_db.address },
        { name = "WORDPRESS_DB_USER", value = "admin" },
        { name = "WORDPRESS_DB_PASSWORD", value = "changeme123!" },
        { name = "WORDPRESS_DB_NAME", value = "wordpress" }
      ]

      mountPoints = [
        {
          sourceVolume  = "wp-content"
          containerPath = "/var/www/html/wp-content"
          readOnly      = false
        }
      ]

      readonlyRootFilesystem = true
      user                   = "1000"
      linuxParameters = {
        capabilities = { drop = ["ALL"] }
      }
    },
    {
      name      = "init"
      image     = "amazonlinux:2"
      essential = false
      entryPoint = ["sh", "-c"]
      command    = ["echo 'Init container placeholder - copy configs if needed'"]
      mountPoints = [
        {
          sourceVolume  = "wp-content"
          containerPath = "/mnt/wp-content"
          readOnly      = false
        }
      ]
    }
  ])
}

# -----------------
# Network Load Balancer (NEW)
# -----------------
resource "aws_lb" "wp_nlb" {
  name               = "wordpress-nlb"
  load_balancer_type = "network"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_lb_target_group" "wp_nlb_tg" {
  name        = "wp-nlb-tg"
  port        = 80
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    protocol = "TCP"
  }
}

resource "aws_lb_listener" "wp_nlb_listener" {
  load_balancer_arn = aws_lb.wp_nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wp_nlb_tg.arn
  }
}

# -----------------
# ECS Service (Fargate)
# -----------------

resource "aws_ecs_service" "wp_service" {
  name            = "wordpress-service"
  cluster         = aws_ecs_cluster.wp_cluster.id
  task_definition = aws_ecs_task_definition.wp_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.wp_tg.arn
    container_name   = "wordpress"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.wp_listener]
}

# -----------------
# AWS WAF (WAFv2)
# -----------------
resource "aws_wafv2_web_acl" "wp_waf" {
  name        = "wordpress-waf"
  description = "WAF for WordPress ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "wordpress-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "common-rules"
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "sqli-rules"
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "bad-inputs-rules"
    }
  }
}

resource "aws_wafv2_web_acl_association" "wp_waf_alb_assoc" {
  resource_arn = aws_lb.wp_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.wp_waf.arn
}

