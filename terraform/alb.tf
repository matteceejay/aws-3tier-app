# ===============================================================
# APPLICATION LOAD BALANCER
# Internet --80--> ALB --8000--> healthy app instances
# ===============================================================


# ---------------------------------------------------------------
# 1. The load balancer
# ---------------------------------------------------------------
resource "aws_lb" "app" {
  name               = "${local.name_prefix}-alb"
  load_balancer_type = "application" # works at HTTP level (Layer 7)

  # internal = false means "internet-facing": AWS gives it a public
  # DNS name. This is why the ALB doesn't need NAT. It sits in public
  # subnets and talks to the internet through the Internet Gateway.
  internal = false

  # Must be in at least 2 public subnets in different AZs.
  # If one AZ fails, the ALB keeps serving from the other.
  subnets = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  # ALB SG from Task 3: 80 in from the internet, 8000 out to the app
  security_groups = [aws_security_group.alb_sg.id]

  # Security hardening: drop malformed HTTP headers instead of
  # passing them to the app (protects against request smuggling).
  drop_invalid_header_fields = true

  # LAB ONLY: allows terraform destroy. Set to true in production.
  enable_deletion_protection = false

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}


# ---------------------------------------------------------------
# 2. Target group: WHERE traffic goes and HOW health is checked
# ---------------------------------------------------------------
resource "aws_lb_target_group" "app" {
  name        = "${local.name_prefix}-app-tg"
  port        = 8000 # gunicorn listens on 8000 (see user data)
  protocol    = "HTTP"
  vpc_id      = aws_vpc.readyjob_vpc.id
  target_type = "instance" # targets are EC2 instance IDs (the ASG registers them)

  # When an instance is removed, give in-flight requests 30 seconds
  # to finish. The default is 300, which makes the lab feel slow.
  deregistration_delay = 30

  # The ALB calls /health on every instance, over and over.
  # Only instances that answer with 200 receive real traffic.
  # We use /health (not /db) on purpose: if the database has a
  # brief problem, we don't want the ALB to mark EVERY instance as
  # unhealthy and take the whole site down.
  health_check {
    path                = "/health"
    port                = "traffic-port" # same port as the targets (8000)
    protocol            = "HTTP"
    matcher             = "200" # only HTTP 200 counts as healthy
    interval            = 15    # check every 15 seconds
    timeout             = 5     # wait at most 5 seconds for an answer
    healthy_threshold   = 2     # 2 passes in a row = healthy
    unhealthy_threshold = 3     # 3 failures in a row = unhealthy
  }

  tags = {
    Name = "${local.name_prefix}-app-tg"
  }
}


# ---------------------------------------------------------------
# 3. Listener: what the ALB does with incoming requests
# ---------------------------------------------------------------
# "Anything that arrives on port 80, forward it to the target group."
# HTTP only for the base lab. In production, you'd add a 443
# listener with an ACM certificate and redirect 80 to 443.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}