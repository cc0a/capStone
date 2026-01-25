# ############################################
# # EFS FILE SYSTEM
# ############################################
# resource "aws_efs_file_system" "wp" {
#   creation_token = "wordpress-efs"
#   encrypted      = true

#   lifecycle_policy {
#     transition_to_ia = "AFTER_30_DAYS"
#   }

#   tags = {
#     Name = "wordpress-efs"
#   }
# }

# ############################################
# # EFS MOUNT TARGETS FOR PRIVATE SUBNETS
# ############################################
# resource "aws_efs_mount_target" "wp" {
#   for_each = aws_subnet.private_app

#   file_system_id  = aws_efs_file_system.wp.id
#   subnet_id       = each.value.id
#   security_groups = [aws_security_group.efs_sg.id]
# }
