# ===============================================================
# OUTPUTS
# Useful, NON-SECRET values printed after terraform apply.
# Never output the database password.
# ===============================================================


# ---------------------------------------------------------------
# Application access
# ---------------------------------------------------------------

# The full URL to open in a browser. This is the first thing
# anyone wants after deploying.
output "app_url" {
  description = "URL of the application (through the ALB)"
  value       = "http://${aws_lb.app.dns_name}"
}

# The raw DNS name. Useful if you later point a Route 53 record at it.
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.app.dns_name
}


# ---------------------------------------------------------------
# Networking
# ---------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.readyjob_vpc.id
}


# ---------------------------------------------------------------
# Compute and load balancing (used in troubleshooting commands)
# ---------------------------------------------------------------

# Needed for: aws elbv2 describe-target-health
output "target_group_arn" {
  description = "ARN of the app target group"
  value       = aws_lb_target_group.app.arn
}

# Needed for: aws autoscaling describe-auto-scaling-groups
output "asg_name" {
  description = "Name of the app Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}


# ---------------------------------------------------------------
# Database (NO password)
# ---------------------------------------------------------------

# The hostname the app connects to. It's private: it only resolves
# to an IP inside the VPC, so sharing it doesn't expose the DB.
output "rds_endpoint" {
  description = "RDS PostgreSQL hostname (private)"
  value       = aws_db_instance.postgres.address
}

output "rds_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.postgres.identifier
}

# The secret's ARN is an ADDRESS, not the password. Knowing it
# doesn't let anyone read the secret. They'd still need IAM
# permission (which only the app role has). It's useful for
# checking the secret with: aws secretsmanager describe-secret
output "db_secret_arn" {
  description = "ARN of the AWS-managed secret holding the DB credentials (not the password itself)"
  value       = aws_db_instance.postgres.master_user_secret[0].secret_arn
}


# Query the instances currently running in the ASG
data "aws_instances" "app" {
  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.app.name]
  }

  depends_on = [aws_autoscaling_group.app]
}

output "asg_instance_ids" {
  description = "Instance IDs of all instances in the app ASG"
  value       = data.aws_instances.app.ids
}