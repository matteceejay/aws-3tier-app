# ===============================================================
# SECURITY GROUPS
# Traffic model:
#   Internet --80--> ALB --8000--> App EC2 --5432--> RDS
#
# Rules:
#   - No SSH (22) anywhere. We use Systems Manager instead (Task 4).
#   - The database never accepts 0.0.0.0/0.
#   - Tiers trust each other by security group, not by IP range.
#
# Note: Terraform removes AWS's default "allow all outbound" rule
# when it creates a security group. So every tier only has the
# outbound access we explicitly give it below.
# ===============================================================


# ---------------------------------------------------------------
# 1. ALB security group (the public entry point)
# ---------------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Allows HTTP from the internet to the ALB"
  vpc_id      = aws_vpc.readyjob_vpc.id

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

# INBOUND: anyone on the internet can reach the ALB on port 80.
# This is the ONLY rule in the whole project open to 0.0.0.0/0,
# because the ALB is the public front door of the app.
resource "aws_vpc_security_group_ingress_rule" "alb_http_from_internet" {
  security_group_id = aws_security_group.alb_sg.id
  description       = "HTTP from the internet"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

# OUTBOUND: the ALB may only forward traffic to the app servers
# on port 8000. It has no reason to talk to anything else.
resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb_sg.id
  description                  = "Forward requests to app instances"
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.app_sg.id
}


# ---------------------------------------------------------------
# 2. App security group (EC2 instances in private subnets)
# ---------------------------------------------------------------
resource "aws_security_group" "app_sg" {
  name        = "${local.name_prefix}-app-sg"
  description = "Allows app traffic from the ALB only"
  vpc_id      = aws_vpc.readyjob_vpc.id

  tags = {
    Name = "${local.name_prefix}-app-sg"
  }
}

# INBOUND: only the ALB can reach the Flask app on port 8000.
# Notice: there is NO port 22 rule. Nobody can SSH in.
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app_sg.id
  description                  = "App port from the ALB only"
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.alb_sg.id
}

# OUTBOUND: HTTPS (443) to the internet, through the NAT Gateway.
# The instances need this to:
#   - register with Systems Manager (Session Manager)
#   - read the DB password from Secrets Manager
#   - download packages (dnf, pip) when they boot
# All of these use HTTPS, so 443 is enough.
resource "aws_vpc_security_group_egress_rule" "app_https_out" {
  security_group_id = aws_security_group.app_sg.id
  description       = "HTTPS to AWS APIs and package repos"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# OUTBOUND: the app may talk to the database on 5432.
resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app_sg.id
  description                  = "PostgreSQL to the database"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.db_sg.id
}


# ---------------------------------------------------------------
# 3. DB security group (RDS PostgreSQL)
# ---------------------------------------------------------------
resource "aws_security_group" "db_sg" {
  name        = "${local.name_prefix}-db-sg"
  description = "Allows PostgreSQL from the app tier only"
  vpc_id      = aws_vpc.readyjob_vpc.id

  tags = {
    Name = "${local.name_prefix}-db-sg"
  }
}

# INBOUND: only app servers can connect to PostgreSQL.
# The database NEVER accepts 0.0.0.0/0.
resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db_sg.id
  description                  = "PostgreSQL from app instances only"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.app_sg.id
}

# OUTBOUND: none.
# The database never needs to START a connection to anything.
# Replies to the app are allowed automatically (stateful).