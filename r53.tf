# ############################################
# # Route 53 Hosted Zone
# ############################################
# resource "aws_route53_zone" "wp_zone" {
#   name = "example.com"  # Replace with your domain
#   comment = "Hosted zone for WordPress environment"
# }

# ###########################################
# # Route 53 Record pointing to ALB
# ###########################################
# resource "aws_route53_record" "wp_alb" {
#   zone_id = aws_route53_zone.wp_zone.zone_id
#   name    = "www.example3388388293.com"  # Replace with your desired subdomain
#   type    = "A"

#   alias {
#     name                   = aws_lb.wp_lb.dns_name
#     zone_id                = aws_lb.wp_lb.zone_id
#     evaluate_target_health = true
#   }
# }