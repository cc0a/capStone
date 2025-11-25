# resource "aws_db_subnet_group" "rds" {
#   name       = "rds-subnet-group"
#   subnet_ids = [
#     aws_subnet.private_rds_a.id,
#     aws_subnet.private_rds_b.id
#   ]
# }

# resource "aws_db_instance" "wordpress_db" {
#   identifier              = "wordpress-db"
#   engine                  = "mysql"
#   engine_version          = "8.0"
#   instance_class          = "db.t3.micro"
#   allocated_storage       = 20
#   db_name                 = "wordpress"
#   username                = "admin"
#   password                = "changeme123!"
#   skip_final_snapshot     = true
#   publicly_accessible     = false

#   vpc_security_group_ids = [aws_security_group.rds_sg.id]
#   db_subnet_group_name   = aws_db_subnet_group.rds.name
# }
