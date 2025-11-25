# # 
# resource "aws_ecr_repository" "wp_repo" {
#   name = "wordpress-hardened"
# }

# resource "aws_iam_role" "ecs_exec" {
#   name = "ecs-task-exec"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Principal = { Service = "ecs-tasks.amazonaws.com" }
#       Action    = "sts:AssumeRole"
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "ecs_exec_attach" {
#   role       = aws_iam_role.ecs_exec.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
# }

# resource "aws_ecs_task_definition" "wp_task" {
#   family                   = "wordpress"
#   network_mode             = "awsvpc"
#   requires_compatibilities = ["FARGATE"]
#   cpu                      = "512"
#   memory                   = "1024"

#   execution_role_arn = aws_iam_role.ecs_exec.arn

#   volume {
#     name = "wp-content"
#     efs_volume_configuration {
#       file_system_id = aws_efs_file_system.wp.id
#       root_directory = "/"
#     }
#   }

#   container_definitions = jsonencode([
#     {
#       name      = "wordpress"
#       image     = "${aws_ecr_repository.wp_repo.repository_url}:latest"
#       essential = true

#       portMappings = [{ containerPort = 80 }]

#       environment = [
#         { name = "WORDPRESS_DB_HOST", value = aws_db_instance.wordpress_db.address },
#         { name = "WORDPRESS_DB_USER", value = "admin" },
#         { name = "WORDPRESS_DB_PASSWORD", value = "changeme123!" },
#         { name = "WORDPRESS_DB_NAME", value = "wordpress" }
#       ]

#       mountPoints = [{
#         sourceVolume  = "wp-content"
#         containerPath = "/var/www/html/wp-content"
#       }]

#       readonlyRootFilesystem = true
#       user = "1000"
#     }
#   ])
# }

# resource "aws_ecs_service" "wp_service" {
#   name            = "wordpress-service"
#   cluster         = aws_ecs_cluster.wp_cluster.id
#   task_definition = aws_ecs_task_definition.wp_task.arn
#   desired_count   = 1
#   launch_type     = "FARGATE"

#   network_configuration {
#     subnets         = [aws_subnet.private_app_a.id, aws_subnet.private_app_b.id]
#     security_groups = [aws_security_group.ecs_sg.id]
#   }

#   load_balancer {
#     target_group_arn = aws_lb_target_group.wp_tg.arn
#     container_name   = "wordpress"
#     container_port   = 80
#   }

#   depends_on = [aws_lb_listener.wp_listener]
# }
