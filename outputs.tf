output "wordpress_alb_dns" {
  value = aws_lb.wp_lb.dns_name
}
