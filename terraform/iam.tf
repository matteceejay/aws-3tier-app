# ===============================================================
# IAM FOR APP EC2 INSTANCES
# Goal: instances can use Systems Manager and read ONLY their
# database secret. No AdministratorAccess, no SSH keys.
# ===============================================================


# ---------------------------------------------------------------
# 1. Trust policy: WHO is allowed to use this role
# ---------------------------------------------------------------
# A role does nothing until something "assumes" (puts on) it.
# This says: only the EC2 service may assume this role.
# Without it, our instances couldn't use the role at all.
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}


# ---------------------------------------------------------------
# 2. The IAM role itself
# ---------------------------------------------------------------
resource "aws_iam_role" "app_role" {
  name               = "${local.name_prefix}-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${local.name_prefix}-app-role"
  }
}


# ---------------------------------------------------------------
# 3. Systems Manager permission
# ---------------------------------------------------------------
# AmazonSSMManagedInstanceCore is an AWS-managed policy with the
# minimum permissions an instance needs to register with Systems
# Manager and accept Session Manager connections.
# This is what replaces SSH: no port 22, no key pair, and every
# session is logged in AWS.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# ---------------------------------------------------------------
# 4. Instance profile
# ---------------------------------------------------------------
# EC2 can't attach a role directly. It needs an "instance profile",
# which is a container that holds the role. The launch template
# in Task 6 will point to this profile.
resource "aws_iam_instance_profile" "app_profile" {
  name = "${local.name_prefix}-app-profile"
  role = aws_iam_role.app_role.name
}


# ---------------------------------------------------------------
# 5. Read ONLY the database secret
# ---------------------------------------------------------------
data "aws_iam_policy_document" "read_db_secret" {
  statement {
    sid = "ReadOnlyTheDatabaseSecret"

    # GetSecretValue = read the password
    # DescribeSecret = read info about the secret (not the value)
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]

    # Least privilege: ONE specific secret, not "*".
    resources = [aws_db_instance.postgres.master_user_secret[0].secret_arn]
  }
}

resource "aws_iam_role_policy" "read_db_secret" {
  name   = "${local.name_prefix}-read-db-secret"
  role   = aws_iam_role.app_role.id
  policy = data.aws_iam_policy_document.read_db_secret.json
}