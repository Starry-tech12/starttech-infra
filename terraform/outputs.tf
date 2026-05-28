output "s3_bucket_name" {
  value = aws_s3_bucket.frontend_bucket.bucket
}

output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}