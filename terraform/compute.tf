# ===============================================================
# COMPUTE: launch template + Auto Scaling Group
# ===============================================================


# ---------------------------------------------------------------
# 1. Launch template: the "recipe" for every app instance
# ---------------------------------------------------------------
# The ASG uses this recipe every time it launches an instance,
# so every instance is identical, including the replacements.
resource "aws_launch_template" "app" {
  name_prefix   = "${local.name_prefix}-app-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  # NO key_name on purpose: no SSH key pair exists for these
  # instances. We connect with Session Manager instead.

  # IAM role from Task 4 (SSM + read the DB secret)
  iam_instance_profile {
    name = aws_iam_instance_profile.app_profile.name
  }

  # App security group from Task 3 (8000 from the ALB only)
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # IMDSv2 required. The metadata service hands out the role's
  # temporary credentials. IMDSv2 needs a session token, which
  # blocks attacks that trick the server into fetching the
  # metadata URL (SSRF) and stealing those credentials.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # this is what enforces IMDSv2
    http_put_response_hop_limit = 1          # token can't leave the instance
  }

  # Encrypt the root disk
  block_device_mappings {
    device_name = "/dev/xvda" # root device name for AL2023

    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Build the boot script. templatefile() fills in the ${...}
  # values, and file() reads the app code from ../app.
  # Launch templates require user data to be base64-encoded.
  user_data = base64encode(templatefile("${path.module}/scripts/user_data.sh.tftpl", {
    app_py           = file("${path.module}/../app/app.py")
    requirements_txt = file("${path.module}/../app/requirements.txt")
    aws_region       = var.aws_region
    db_host          = aws_db_instance.postgres.address # hostname only, no port
    db_name          = var.db_name
    db_secret_arn    = aws_db_instance.postgres.master_user_secret[0].secret_arn
  }))

  # Tags applied to each instance and its disk when launched.
  # The Name tag is what the Task 4 checkpoint commands search for.
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name_prefix}-app"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${local.name_prefix}-app-volume"
    }
  }
}


# ---------------------------------------------------------------
# 2. Auto Scaling Group: keeps the right number of instances running
# ---------------------------------------------------------------
# If an instance dies or is terminated, the ASG notices it is
# below the desired count and launches a replacement.
resource "aws_autoscaling_group" "app" {
  name = "${local.name_prefix}-app-asg"

  # Private app subnets ONLY, one per AZ. The ASG spreads
  # instances across both, so losing one AZ doesn't take the app down.
  vpc_zone_identifier = [aws_subnet.app_1.id, aws_subnet.app_2.id]

  min_size         = var.asg_min_size
  desired_capacity = var.asg_desired_capacity
  max_size         = var.asg_max_size

  # Always use the newest version of the launch template
  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  # Attach the ASG to the target group. The ASG automatically
  # registers every new instance with the ALB, and deregisters
  # instances it removes. No manual registration is needed.
  target_group_arns = [aws_lb_target_group.app.arn]

  # "ELB" = replace an instance if it fails EITHER the EC2 status
  # check OR the ALB's /health check. With "EC2" only, a server
  # whose app crashed would keep running forever and never be fixed.
  health_check_type = "ELB"

  # Give new instances 5 minutes to boot and install before
  # health checks count against them.
  health_check_grace_period = 300

  # When the launch template changes (new AMI, new app code),
  # replace instances gradually, keeping at least half running.
  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }
  }

  # Send ASG metrics (instance counts) to CloudWatch. These are free.
  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances",
  ]
}