variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name, used as a prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the application tier"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}


variable "db_name" {
  description = "Name of the database created inside PostgreSQL (the app expects appdb)"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for PostgreSQL (the password is managed by AWS)"
  type        = string
  default     = "appadmin"
}

variable "db_engine_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "17"
}

variable "asg_min_size" {
  description = "Minimum number of app instances"
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Desired number of app instances"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of app instances"
  type        = number
  default     = 4

  validation {
    condition     = var.asg_max_size >= var.asg_min_size
    error_message = "asg_max_size must be greater than or equal to asg_min_size."
  }
}