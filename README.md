# Project 1 — AWS 3-Tier Terraform Job-Readiness Assignment

This is a **build-it-yourself DevOps lab**, not a copy-and-run Terraform repository. The application is provided; the student writes the infrastructure code.

## Scenario

You have joined a team that needs a small production-shaped web application on AWS. Your assignment is to provision the environment with Terraform, validate it, troubleshoot failures, and explain your design in an interview.

## Target architecture

```text
Internet
   |
   v
Application Load Balancer
(public subnets / 2 AZs)
   |
   v
EC2 Auto Scaling Group
(private app subnets / 2 AZs)
   |
   v
Amazon RDS PostgreSQL
(private DB subnets)

Supporting: IAM + SSM + Secrets Manager + NAT + S3 Terraform state
```

See `architecture/architecture.md` for the detailed design.

## What is provided vs. what you build

### Provided

- `app/` — small Flask application
- `architecture/` — target architecture and design decisions
- `validation/` — deployment acceptance checklist
- `troubleshooting/` — break/fix scenarios
- `interview-prep/` — questions and STAR prompts
- `.github/workflows/` — CI structure/checks

### You build

- `bootstrap/` — remote-state Terraform
- `terraform/` — **all AWS infrastructure Terraform**
- `terraform/scripts/user_data.sh.tftpl` — EC2 bootstrap logic

There is intentionally no completed Terraform solution in the student repository.

## Learning objectives

By the end, you should be able to build and explain:

- Terraform providers, variables, locals, data sources, resources and outputs
- S3 remote state and state locking
- VPC networking across two Availability Zones
- public, private-app and private-DB subnets
- IGW, NAT Gateway, routes and route tables
- least-privilege security-group paths
- IAM instance roles and Systems Manager
- RDS PostgreSQL and Secrets Manager credentials
- EC2 launch templates and Auto Scaling Groups
- Application Load Balancer, target groups and health checks
- validation and production-style troubleshooting

## Recommended workflow

**Phase 1:** Complete `bootstrap/ASSIGNMENT.md`.

**Phase 2:** Complete the tasks in `terraform/ASSIGNMENT.md` in order. Do not build everything in one large `main.tf`; organize the code so another engineer can review it.

**Phase 3:** Run `terraform fmt`, `terraform validate`, `terraform plan`, and deploy.

**Phase 4:** Complete every item in `validation/checklist.md`.

**Phase 5:** Work through `troubleshooting/scenarios.md` without immediately reading or asking for a solution. Capture the symptom, investigation, root cause, fix and prevention.

**Phase 6:** Use `interview-prep/questions.md` and explain the architecture aloud in 2–3 minutes.

## Rules for students

1. Do not commit `.tfstate`, `.tfstate.backup`, `terraform.tfvars`, backend credentials, passwords, or secrets.
2. Do not open SSH to the Internet; use Systems Manager.
3. Do not make RDS publicly accessible.
4. Do not use `0.0.0.0/0` for PostgreSQL.
5. Do not hardcode an RDS password in Terraform.
6. Do not hardcode an AMI ID when a suitable data source can discover it.
7. Every `terraform apply` should be preceded by reading the plan.
8. Be able to explain code you submit.

## Cost warning

This lab creates billable resources, especially NAT Gateway, ALB, EC2 and RDS. Destroy the environment when practice is complete:

```bash
terraform destroy
```

The base assignment intentionally uses one NAT Gateway and permits Single-AZ RDS to keep a training environment cheaper. For the production discussion, explain the availability trade-offs.

## Stretch goals — only after the base project works

Add HTTPS with ACM, Route 53, WAF, CloudWatch alarms, NAT per AZ, Multi-AZ RDS, deletion protection/final snapshots, VPC endpoints, and a deployment strategy such as blue/green.

## Interview outcome

You should finish this project able to say, truthfully:

> I built a three-tier AWS environment with Terraform. I designed the VPC and subnet routing, restricted traffic between the ALB, application and database tiers with security groups, deployed the application with an Auto Scaling Group, kept PostgreSQL private, used IAM/Systems Manager and Secrets Manager, configured remote Terraform state, and troubleshot failures such as unhealthy targets and database connectivity.










#BOOTSTRAP DECISION

Application bootstrap: The app code (app/app.py, app/requirements.txt) is embedded into EC2 user data with Terraform's templatefile() and file(). On boot, each instance installs Python 3.12, creates a virtualenv, installs dependencies, and runs the app with gunicorn as a systemd service on port 8000. This avoids an extra S3 bucket or Git access from private instances, and the app is small enough for the 16 KB user data limit. A code change creates a new launch template version, and the ASG's instance refresh rolls it out. Database settings (host, name, secret ARN) go into /etc/app.env. The password is never written to disk; the app reads it from Secrets Manager at runtime using its IAM role.