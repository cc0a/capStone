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
  newbits        = 4
}

# ======================================================
# VPC
# ======================================================
resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "wordpress-vpc" }
}

# ======================================================
# PUBLIC SUBNETS
# ======================================================
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidr_block, local.newbits, 0)
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidr_block, local.newbits, 1)
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  tags = { Name = "public-b" }
}

# ======================================================
# PRIVATE APP SUBNETS (ECS)
# ======================================================
resource "aws_subnet" "private_app_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidr_block, local.newbits, 2)
  availability_zone = "us-east-1a"
  tags = { Name = "private-app-a" }
}

resource "aws_subnet" "private_app_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidr_block, local.newbits, 3)
  availability_zone = "us-east-1b"
  tags = { Name = "private-app-b" }
}

# ======================================================
# PRIVATE RDS SUBNETS
# ======================================================
resource "aws_subnet" "private_rds_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidr_block, local.newbits, 4)
  availability_zone = "us-east-1c"
  tags = { Name = "private-rds-a" }
}

resource "aws_subnet" "private_rds_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidr_block, local.newbits, 5)
  availability_zone = "us-east-1d"
  tags = { Name = "private-rds-b" }
}

# ======================================================
# INTERNET GATEWAY + PUBLIC ROUTE TABLE
# ======================================================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_a" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_a.id
}

resource "aws_route_table_association" "public_b" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_b.id
}

# ======================================================
# NAT GATEWAY + PRIVATE ROUTES (NEEDED FOR FARGATE)
# ======================================================
resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_a.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private_app_a" {
  subnet_id      = aws_subnet.private_app_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_app_b" {
  subnet_id      = aws_subnet.private_app_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_rds_a" {
  subnet_id      = aws_subnet.private_rds_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_rds_b" {
  subnet_id      = aws_subnet.private_rds_b.id
  route_table_id = aws_route_table.private.id
}

# ======================================================
# SECURITY GROUPS
# ======================================================
resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_security_group" "ecs_sg" {
  name   = "ecs-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds_sg" {
  name   = "rds-sg"
  vpc_id = aws_vpc.main.id

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

resource "aws_security_group" "elasticache_sg" {
  name   = "elasticache-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 6379
    to_port         = 6379
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

# ======================================================
# RDS SUBNET GROUP + INSTANCE
# ======================================================
resource "aws_db_subnet_group" "rds" {
  name       = "rds-subnet-group"
  subnet_ids = [
    aws_subnet.private_rds_a.id,
    aws_subnet.private_rds_b.id
  ]
}

resource "aws_db_instance" "wordpress_db" {
  identifier              = "wordpress-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "wordpress"
  username                = "admin"
  password                = "changeme123!"
  skip_final_snapshot     = true
  publicly_accessible     = false

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds.name
}

# ======================================================
# EFS FOR WORDPRESS wp-content
# ======================================================
resource "aws_efs_file_system" "wp" {
  creation_token = "wp-content"
  encrypted      = true
}

resource "aws_efs_mount_target" "a" {
  file_system_id  = aws_efs_file_system.wp.id
  subnet_id       = aws_subnet.private_app_a.id
  security_groups = [aws_security_group.ecs_sg.id]
}

resource "aws_efs_mount_target" "b" {
  file_system_id  = aws_efs_file_system.wp.id
  subnet_id       = aws_subnet.private_app_b.id
  security_groups = [aws_security_group.ecs_sg.id]
}

# ======================================================
# ECS CLUSTER
# ======================================================
resource "aws_ecs_cluster" "wp_cluster" {
  name = "wordpress-cluster"
}

# ======================================================
# ECR
# ======================================================
resource "aws_ecr_repository" "wp_repo" {
  name = "wordpress-hardened"
}

# ======================================================
# ECS TASK DEFINITION (HARDENED)
# ======================================================
resource "aws_iam_role" "ecs_exec" {
  name = "ecs-task-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_attach" {
  role       = aws_iam_role.ecs_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "wp_task" {
  family                   = "wordpress"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"

  execution_role_arn = aws_iam_role.ecs_exec.arn

  volume {
    name = "wp-content"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.wp.id
      root_directory = "/"
    }
  }

  container_definitions = jsonencode([
    {
      name      = "wordpress"
      image     = "${aws_ecr_repository.wp_repo.repository_url}:latest"
      essential = true

      portMappings = [{ containerPort = 80 }]

      environment = [
        { name = "WORDPRESS_DB_HOST", value = aws_db_instance.wordpress_db.address },
        { name = "WORDPRESS_DB_USER", value = "admin" },
        { name = "WORDPRESS_DB_PASSWORD", value = "changeme123!" },
        { name = "WORDPRESS_DB_NAME", value = "wordpress" }
      ]

      mountPoints = [{
        sourceVolume  = "wp-content"
        containerPath = "/var/www/html/wp-content"
      }]

      readonlyRootFilesystem = true
      user = "1000"
    }
  ])
}

# ======================================================
# ALB (CLEAN + CORRECT)
# ======================================================
resource "aws_lb" "wp_alb" {
  name               = "wp-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}

resource "aws_lb_target_group" "wp_tg" {
  name        = "wp-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path = "/"
  }
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

# ======================================================
# ECS SERVICE (FARGATE)
# ======================================================
resource "aws_ecs_service" "wp_service" {
  name            = "wordpress-service"
  cluster         = aws_ecs_cluster.wp_cluster.id
  task_definition = aws_ecs_task_definition.wp_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private_app_a.id, aws_subnet.private_app_b.id]
    security_groups = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.wp_tg.arn
    container_name   = "wordpress"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.wp_listener]
}

# ======================================================
# WAFv2 (FIXED SYNTAX)
# ======================================================
resource "aws_wafv2_web_acl" "wp_waf" {
  name        = "wordpress-waf"
  description = "WAF for WordPress"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "waf"
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
      metric_name                = "common"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_wafv2_web_acl_association" "wp_waf_assoc" {
  resource_arn = aws_lb.wp_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.wp_waf.arn
}

# ======================================================
# REDIS
# ======================================================
resource "aws_elasticache_subnet_group" "redis_sn" {
  name       = "redis-subnets"
  subnet_ids = [
    aws_subnet.private_app_a.id,
    aws_subnet.private_app_b.id
  ]
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id         = "wordpress-redis"
  engine             = "redis"
  node_type          = "cache.t3.micro"
  num_cache_nodes    = 1
  port               = 6379
  subnet_group_name  = aws_elasticache_subnet_group.redis_sn.name
  security_group_ids = [aws_security_group.elasticache_sg.id]
}

# ======================================================
# VPC FLOW LOGS → S3
# ======================================================
resource "aws_s3_bucket" "vpc_logs" {
  bucket = "my-vpc-flow-logs-bucket-12345"
}

resource "aws_s3_bucket_lifecycle_configuration" "vpc_logs" {
  bucket = aws_s3_bucket.vpc_logs.id

  rule {
    id     = "logs"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 365
    }
  }
}

# ======================================================
# LAMBDA FOR RDS SNAPSHOTS
# ======================================================
resource "aws_iam_role" "snapshot_role" {
  name = "snapshot-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "snapshot_policy" {
  name = "rds-snapshot"
  role = aws_iam_role.snapshot_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "rds:CreateDBSnapshot",
          "rds:DescribeDBInstances"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "rds_snapshot" {
  filename      = "rds_snapshot_lambda.zip"
  function_name = "rds-snapshot"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.10"
  role          = aws_iam_role.snapshot_role.arn
}

resource "aws_cloudwatch_event_rule" "snapshot_rule" {
  name                = "rds-snapshot-every-30-days"
  schedule_expression = "rate(30 days)"
}

resource "aws_cloudwatch_event_target" "snapshot_target" {
  rule      = aws_cloudwatch_event_rule.snapshot_rule.name
  target_id = "snapshot"
  arn       = aws_lambda_function.rds_snapshot.arn
}

resource "aws_lambda_permission" "snapshot_invoke" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rds_snapshot.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.snapshot_rule.arn
}
