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
