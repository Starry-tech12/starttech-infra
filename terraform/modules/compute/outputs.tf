output "alb_dns_name" {
  value = aws_lb.api_alb.dns_name
}

output "instance_sg_id" {
  value = aws_security_group.instance_sg.id
}