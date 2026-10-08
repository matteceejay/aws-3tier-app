# ===============================================================
# DATA SOURCES: things we LOOK UP from AWS (we don't create them)
# ===============================================================

# ---------------------------------------------------------------
# 1. Availability Zones (used in network.tf, Task 2)
# ---------------------------------------------------------------
# Instead of hardcoding "us-east-1a" and "us-east-1b", we ask AWS
# which AZs are available, so the code still works if we change regions.
data "aws_availability_zones" "available_region" {
  state = "available" # only AZs that are currently working
}

# ---------------------------------------------------------------
# 2. Amazon Linux 2023 AMI (used in compute.tf, Task 6)
# ---------------------------------------------------------------
# Find the latest AL2023 image instead of hardcoding an AMI ID.
# AMI IDs differ per region and change whenever AWS releases a
# patched image, so a hardcoded ID goes stale.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"] # only official images published by AWS

  filter {
    # Standard AL2023 image (this pattern excludes the "minimal" variant)
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    # t3.micro is an Intel/AMD instance, so we need x86_64
    name   = "architecture"
    values = ["x86_64"]
  }
}