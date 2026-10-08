# ===============================================================
# VPC
# ===============================================================

# The VPC is our private network inside AWS. Everything else
# (subnets, EC2, RDS, ALB) lives inside it.
resource "aws_vpc" "readyjob_vpc" {
  cidr_block = var.vpc_cidr

  # DNS translates human-readable names (like the RDS endpoint or
  # the Systems Manager endpoint) into IP addresses.
  # enable_dns_support   -> instances can use the VPC's built-in DNS resolver
  # enable_dns_hostnames -> instances get DNS names, not just IPs
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

# ===============================================================
# Internet Gateway
# ===============================================================

# The Internet Gateway is the "front door" between the VPC and the
# internet. Without it, nothing in the VPC can reach the internet,
# and the internet can't reach our ALB.
resource "aws_internet_gateway" "readyjob_igw" {
  vpc_id = aws_vpc.readyjob_vpc.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

# ===============================================================
# Public subnets (ALB + NAT Gateway)
# ===============================================================

# Public subnets are "public" because their route table sends
# internet traffic to the Internet Gateway (see route tables below).
# We need two of them in different AZs because an ALB requires
# at least two AZs.

resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.readyjob_vpc.id
  cidr_block        = local.public_subnet_cidrs[0]
  availability_zone = data.aws_availability_zones.available_region.names[0]

  # We do NOT auto-assign public IPs. The ALB and NAT Gateway get
  # their own public addresses, so nothing else here needs one.
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-public-1"
    Tier = "public"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.readyjob_vpc.id
  cidr_block              = local.public_subnet_cidrs[1]
  availability_zone       = data.aws_availability_zones.available_region.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-public-2"
    Tier = "public"
  }
}

# ===============================================================
# Private application subnets (EC2 instances)
# ===============================================================

# App servers live here. They have no public IP and cannot be
# reached directly from the internet. Only the ALB can talk to them.

resource "aws_subnet" "app_1" {
  vpc_id            = aws_vpc.readyjob_vpc.id
  cidr_block        = local.app_subnet_cidrs[0]
  availability_zone = data.aws_availability_zones.available_region.names[0]

  tags = {
    Name = "${local.name_prefix}-app-1"
    Tier = "app"
  }
}

resource "aws_subnet" "app_2" {
  vpc_id            = aws_vpc.readyjob_vpc.id
  cidr_block        = local.app_subnet_cidrs[1]
  availability_zone = data.aws_availability_zones.available_region.names[1]

  tags = {
    Name = "${local.name_prefix}-app-2"
    Tier = "app"
  }
}

# ===============================================================
# Private database subnets (RDS)
# ===============================================================

# The database gets its own subnets, separate from the app tier.
# RDS requires a subnet group with subnets in at least two AZs,
# even for a Single-AZ database.

resource "aws_subnet" "db_1" {
  vpc_id            = aws_vpc.readyjob_vpc.id
  cidr_block        = local.db_subnet_cidrs[0]
  availability_zone = data.aws_availability_zones.available_region.names[0]

  tags = {
    Name = "${local.name_prefix}-db-1"
    Tier = "db"
  }
}

resource "aws_subnet" "db_2" {
  vpc_id            = aws_vpc.readyjob_vpc.id
  cidr_block        = local.db_subnet_cidrs[1]
  availability_zone = data.aws_availability_zones.available_region.names[1]

  tags = {
    Name = "${local.name_prefix}-db-2"
    Tier = "db"
  }
}

# ===============================================================
# NAT Gateway + Elastic IP
# ===============================================================

# Private EC2 instances need to reach the internet OUTBOUND only:
# to download packages (dnf, pip) and talk to AWS services
# (Systems Manager, Secrets Manager). The NAT Gateway allows that
# while still blocking all inbound connections from the internet.

# The NAT Gateway needs a fixed public IP address: an Elastic IP.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip"
  }
}

# The NAT Gateway must sit in a PUBLIC subnet, because it needs
# the Internet Gateway to reach the internet itself.
# For the lab we use ONE NAT Gateway to save money. In production,
# you'd use one per AZ so losing one AZ doesn't cut off the other.
resource "aws_nat_gateway" "readyjob_nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "${local.name_prefix}-nat"
  }

  # Make sure the Internet Gateway exists first. Otherwise the
  # NAT Gateway has no path to the internet.
  depends_on = [aws_internet_gateway.readyjob_igw]
}

# ===============================================================
# Route tables
# ===============================================================

# A route table is a set of directions: "traffic going to X, send
# it through Y". Every VPC automatically knows how to reach its own
# CIDR (10.20.0.0/16), so we only add routes for the internet.

# --- Public route table: internet traffic -> Internet Gateway ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.readyjob_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # "anywhere on the internet"
    gateway_id = aws_internet_gateway.readyjob_igw.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

# --- App route table: internet traffic -> NAT Gateway ---
# Outbound only. The internet cannot start a connection to the
# instances through NAT.
resource "aws_route_table" "app" {
  vpc_id = aws_vpc.readyjob_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.readyjob_nat.id
  }

  tags = {
    Name = "${local.name_prefix}-app-rt"
  }
}

# --- DB route table: NO internet route at all ---
# The database only needs to talk to the app servers inside the
# VPC, and that is covered by the automatic local route.
# No 0.0.0.0/0 route means no path to or from the internet.
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.readyjob_vpc.id

  tags = {
    Name = "${local.name_prefix}-db-rt"
  }
}

# ===============================================================
# Route table associations
# ===============================================================

# A subnet doesn't use a route table until we connect them.
# Without these, subnets fall back to the VPC's default "main"
# route table (created automatically by AWS), which is not what we want.

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app_1" {
  subnet_id      = aws_subnet.app_1.id
  route_table_id = aws_route_table.app.id
}

resource "aws_route_table_association" "app_2" {
  subnet_id      = aws_subnet.app_2.id
  route_table_id = aws_route_table.app.id
}

resource "aws_route_table_association" "db_1" {
  subnet_id      = aws_subnet.db_1.id
  route_table_id = aws_route_table.db.id
}

resource "aws_route_table_association" "db_2" {
  subnet_id      = aws_subnet.db_2.id
  route_table_id = aws_route_table.db.id
}