############################################
# ECR REPO
############################################
resource "aws_ecr_repository" "wordpress" {
  name = "wordpress-app"
}

############################################
# ECS CLUSTER
############################################
resource "aws_ecs_cluster" "wp_cluster" {
  name = "wordpress-cluster"
}

############################################
# ECS TASK EXECUTION ROLE
############################################
resource "aws_iam_role" "ecs_task_execution" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

############################################
# ECS TASK ROLE (optional, minimal)
############################################
resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

############################################
# CLOUDWATCH LOG GROUP
############################################
resource "aws_cloudwatch_log_group" "wordpress" {
  name              = "/ecs/wordpress"
  retention_in_days = 14
}

############################################
# ECS TASK DEFINITION – WORDPRESS
############################################
resource "aws_ecs_task_definition" "wordpress" {
  family                   = "wordpress"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"

  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  ##########################################
  # CONTAINER DEFINITION
  ##########################################
  container_definitions = jsonencode([
    {
      name      = "wordpress"
      image     = "${aws_ecr_repository.wordpress.repository_url}:latest"
      essential = true

      portMappings = [
        { containerPort = 80, protocol = "tcp" }
      ]

      environment = [
        { name = "WORDPRESS_DB_HOST", value = aws_db_instance.wordpress_db.address },
        { name = "WORDPRESS_DB_USER", value = "admin" },
        { name = "WORDPRESS_DB_PASSWORD", value = var.db_password },
        { name = "WORDPRESS_DB_NAME", value = "wordpress" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.wordpress.name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

############################################
# ECS SERVICE
############################################
resource "aws_ecs_service" "wordpress" {
  name            = "wordpress-service"
  cluster         = aws_ecs_cluster.wp_cluster.id
  task_definition = aws_ecs_task_definition.wordpress.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [for subnet in aws_subnet.private_app : subnet.id]
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.wp_tg.arn
    container_name   = "wordpress"
    container_port   = 80
  }

  depends_on = [
    aws_lb_listener.wp_listener
  ]
}
