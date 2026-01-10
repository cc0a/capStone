############################################
# SECURITY GROUP FOR ALB
############################################
resource "aws_security_group" "lb_sg" {
  name        = "wordpress-lb-sg"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.main.id

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

  tags = {
    Name = "wordpress-lb-sg"
  }
}

############################################
# APPLICATION LOAD BALANCER
############################################
resource "aws_lb" "wp_lb" {
  name               = "wordpress-alb"
  internal           = false
  load_balancer_type = "application"
  
  # Use multi-AZ public subnets
  subnets = [
    aws_subnet.public["us-east-1a"].id,
    aws_subnet.public["us-east-1b"].id
  ]

  security_groups = [aws_security_group.lb_sg.id]

  tags = {
    Name = "wordpress-alb"
  }
}

############################################
# TARGET GROUP
############################################
resource "aws_lb_target_group" "wp_tg" {
  name     = "wordpress-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }

  tags = {
    Name = "wordpress-tg"
  }
}

############################################
# LISTENER
############################################
resource "aws_lb_listener" "wp_listener" {
  load_balancer_arn = aws_lb.wp_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wp_tg.arn
  }
}

