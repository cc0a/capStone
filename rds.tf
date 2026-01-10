############################################
# DB SUBNET GROUP (MULTI-AZ)
############################################
resource "aws_db_subnet_group" "rds" {
  name       = "rds-subnet-group"
  subnet_ids = [for subnet in aws_subnet.private_rds : subnet.id]

  tags = {
    Name = "wordpress-rds-subnet-group"
  }
}

############################################
# RDS INSTANCE
############################################
resource "aws_db_instance" "wordpress_db" {
  identifier              = "wordpress-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "wordpress"
  username                = "admin"
  password                = var.db_password
  skip_final_snapshot     = true
  publicly_accessible     = false

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds.name

  multi_az               = true
  apply_immediately      = true

  tags = {
    Name = "wordpress-db"
  }
}