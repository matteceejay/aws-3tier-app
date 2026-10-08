#!/bin/bash
# Quick end-to-end check of the 3-tier environment.
# Run from the terraform/ folder after apply.

APP_URL=$(terraform output -raw app_url)
TG_ARN=$(terraform output -raw target_group_arn)
ASG=$(terraform output -raw asg_name)
DB_ID=$(terraform output -raw rds_identifier)

echo "=== 1. App responds through the ALB ==="
curl -s "$APP_URL/health"; echo
curl -s "$APP_URL/db"; echo

echo "=== 2. Two healthy targets ==="
aws elbv2 describe-target-health --target-group-arn "$TG_ARN" \
  --query "TargetHealthDescriptions[].[Target.Id, TargetHealth.State]" --output table

echo "=== 3. ASG instances spread across two AZs ==="
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" \
  --query "AutoScalingGroups[0].Instances[].[InstanceId, AvailabilityZone, HealthStatus]" --output table

echo "=== 4. Database is private and encrypted ==="
aws rds describe-db-instances --db-instance-identifier "$DB_ID" \
  --query "DBInstances[0].{Public:PubliclyAccessible, Encrypted:StorageEncrypted}" --output table

echo "=== 5. No port 22 rules anywhere (should be empty) ==="
aws ec2 describe-security-group-rules --query "SecurityGroupRules[?FromPort==\`22\`].GroupId" --output text

echo "=== 6. No password in state (should be empty) ==="
terraform state pull | grep -i '"password"' || echo "OK: no password in state"