resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "starttech-esther-2026-${random_id.suffix.hex}"

  tags = {
    Name        = "StartTech Frontend Bucket"
    Environment = "Production"
  }
}

resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "starttech-vpc"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = { Name = "public-subnet-1" }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = { Name = "public-subnet-2" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# SECURITY GROUPS
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main_vpc.id

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
}

resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["105.117.2.3/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# CLOUDWATCH LOG GROUP
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "starttech-logs"
  retention_in_days = 7
}

# IAM FOR CLOUDWATCH
resource "aws_iam_role" "ec2_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cw_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  role = aws_iam_role.ec2_role.name
}

# LOAD BALANCER
resource "aws_lb" "alb" {
  name               = "starttech-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}

resource "aws_lb_target_group" "tg" {
  name     = "backend-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id

  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# LAUNCH TEMPLATE
resource "aws_launch_template" "backend" {
  name_prefix   = "backend-template"
  image_id      = "ami-0d5e7e27578d32e47"
  instance_type = "t3.micro"
  key_name      = "starttech-key"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  user_data = base64encode(<<EOF
#!/bin/bash
yum update -y
yum install -y docker amazon-cloudwatch-agent

systemctl start docker
systemctl enable docker

mkdir -p /home/ec2-user/site

cat <<HTML > /home/ec2-user/site/index.html
<html>
  <body>
    <h1>StartTech Running 🚀</h1>
  </body>
</html>
HTML

cat <<CW > /opt/aws/amazon-cloudwatch-agent/bin/config.json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "starttech-logs",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
CW

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
-a fetch-config -m ec2 \
-c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s

systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

docker run -d \
  -p 8080:80 \
  -e MONGO_URI="mongodb+srv://estherisaiah2000_db_user:Starryayo12345@cluster0.mlwu6bq.mongodb.net/?appName=Cluster0" \
  127259106152.dkr.ecr.us-east-1.amazonaws.com/starttech-backend:latest
EOF
)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "backend-instance"
    }
  }
}

# AUTO SCALING
resource "aws_autoscaling_group" "asg" {
  desired_capacity    = 2
  max_size           = 3
  min_size           = 1
  vpc_zone_identifier = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]

  target_group_arns = [aws_lb_target_group.tg.arn]

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  health_check_type = "EC2"
}