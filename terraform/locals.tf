locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  # ---------------------------------------------------------------
  # Subnet CIDR plan (documented here so it lives in one place)
  # Public: 10.20.1.x / 10.20.2.x   -> ALB and NAT Gateway
  # App:    10.20.11.x / 10.20.12.x -> EC2 instances (private)
  # DB:     10.20.21.x / 10.20.22.x -> RDS (private, no internet)
  # ---------------------------------------------------------------
  # /24s carved out of the VPC CIDR
  public_subnet_cidrs = ["10.20.0.0/24", "10.20.1.0/24"]
  app_subnet_cidrs    = ["10.20.10.0/24", "10.20.11.0/24"]
  db_subnet_cidrs     = ["10.20.20.0/24", "10.20.21.0/24"]
}