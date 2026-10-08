output "state_bucket_name" {
  description = "Name of the S3 bucket used for remote state"
  value       = var.bucket_name
}

output "aws_region" {
    description = "AWS region where the state bucket is located"
    value       = var.aws_region
}