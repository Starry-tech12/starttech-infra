resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/starttech/production/backend"
  retention_in_days = 7

  tags = {
    Environment = "production"
    Application = "backend-api"
  }
}