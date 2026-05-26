# Private Subnet Group for ElastiCache
resource "aws_elasticache_subnet_group" "redis_subnets" {
  name       = "starttech-redis-subnet-group"
  subnet_ids = var.private_subnet_ids
}

# Firewalled Security Group for Cache Nodes
resource "aws_security_group" "redis_sg" {
  name        = "starttech-${var.environment}-redis-sg"
  description = "Restrict access to ElastiCache Cluster from API layer"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.instance_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# The ElastiCache Redis Cluster
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "starttech-redis-${var.environment}"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnets.name
  security_group_ids   = [aws_security_group.redis_sg.id]
}