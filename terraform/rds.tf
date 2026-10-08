# ===============================================================
# RDS POSTGRESQL (DATABASE TIER)
# - Lives only in the private DB subnets
# - Not publicly accessible
# - Storage encrypted
# - Password created and stored by AWS in Secrets Manager
# ===============================================================


# ---------------------------------------------------------------
# 1. DB subnet group
# ---------------------------------------------------------------
# Tells RDS which subnets it is allowed to use. We give it ONLY
# the two private DB subnets, so the database can never be placed
# in a public subnet. RDS requires subnets in at least two AZs,
# even for a Single-AZ database. That's also what makes it
# possible to switch to Multi-AZ later.
resource "aws_db_subnet_group" "db_subnets" {
  name        = "${local.name_prefix}-db-subnet-group"
  description = "Private DB subnets for PostgreSQL"
  subnet_ids  = [aws_subnet.db_1.id, aws_subnet.db_2.id]

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}


# ---------------------------------------------------------------
# 2. PostgreSQL instance
# ---------------------------------------------------------------
resource "aws_db_instance" "postgres" {
  identifier = "${local.name_prefix}-postgres"

  # --- Engine ---
  engine                     = "postgres"
  engine_version             = var.db_engine_version # major version only
  auto_minor_version_upgrade = true                  # AWS applies security patches
  instance_class             = var.db_instance_class

  # --- Storage ---
  allocated_storage = 20    # GB, the minimum
  storage_type      = "gp3" # current-generation SSD
  storage_encrypted = true  # data at rest is encrypted with KMS

  # --- Database and login ---
  # db_name creates the "appdb" database on first boot, because
  # the app connects to it by name.
  db_name  = var.db_name
  username = var.db_username
  port     = 5432

  # AWS generates a strong password and stores it in Secrets
  # Manager. It never appears in Terraform code, tfvars, Git,
  # or user data. The app reads it at runtime with its IAM role.
  manage_master_user_password = true

  # --- Network: private only ---
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids = [aws_security_group.db_sg.id] # only the app SG can reach 5432
  publicly_accessible    = false                         # no public IP or public DNS answer

  # --- Availability ---
  # Single-AZ keeps lab costs down. Set to true for the stretch
  # goal: AWS keeps a standby copy in the second AZ.
  multi_az = false

  # --- Backups and lab-friendly teardown ---
  backup_retention_period = 1     # keep 1 day of automatic backups
  skip_final_snapshot     = true  # LAB ONLY: lets terraform destroy finish cleanly
  deletion_protection     = false # LAB ONLY: in production, set this to true
  apply_immediately       = true  # apply changes now, not in the next maintenance window

  tags = {
    Name = "${local.name_prefix}-postgres"
  }
}