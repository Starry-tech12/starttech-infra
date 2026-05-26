# --- SECURITY GROUPS ---

# External ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "starttech-${var.environment}-alb-sg"
  description = "Allow public HTTP traffic to ALB"
  vpc_id      = var.vpc_id

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

  tags = { Name = "starttech-alb-sg" }
}

# Private EC2 Instance Security Group
resource "aws_security_group" "instance_sg" {
  name        = "starttech-${var.environment}-instance-sg"
  description = "Allow traffic exclusively from ALB to Golang API"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "starttech-instance-sg" }
}

# --- IAM ROLES & INSTANCE PROFILES ---

resource "aws_iam_role" "ec2_role" {
 # Change the naming string to keep it distinct
  name = "starttech-${var.environment}-ec2-execution-role"
# ... leave your assume_role_policy exactly as it was

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

# Attach core managed policy for CloudWatch Logs Agent and Systems Manager Access
resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "starttech-${var.environment}-ec2-execution-profile"
  role = aws_iam_role.ec2_role.name
}

# --- APPLICATION LOAD BALANCER ---

resource "aws_lb" "api_alb" {
  name               = "starttech-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids

  tags = { Name = "starttech-alb" }
}

resource "aws_lb_target_group" "api_tg" {
  name     = "starttech-${var.environment}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = "/health"
    port                = "8080"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.api_alb.arn
  port              = "8080" # Listening on 8080 for matching your application config or port 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_tg.arn
  }
}

# --- AUTO SCALING GROUP (ASG) ---

resource "aws_launch_template" "api_lt" {
  name_prefix   = "starttech-api-template-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.instance_sg.id]
  }

  # Installs Docker, CloudWatch Agent, and sets up initialization variables on boot
  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y apt-transport-https ca-certificates curl software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
              add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              apt-get update -y
              apt-get install -y docker-ce amazon-cloudwatch-agent
              systemctl start docker
              systemctl enable docker
              EOF
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "api_asg" {
  name_prefix         = "starttech-asg-"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.api_tg.arn]

  min_size         = 2
  max_size         = 5
  desired_capacity = 2

  launch_template {
    id      = aws_launch_template.api_lt.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300

  force_delete          = true
  wait_for_capacity_timeout = "0"

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["tag"]
  }

  tag {
    key                 = "Name"
    value               = "starttech-api-worker"
    propagate_at_launch = true
  }
}