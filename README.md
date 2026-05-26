# Auto Scaling Web Tier Lab

This repository contains a CloudFormation template for a public Application Load Balancer that serves a private, multi-AZ EC2 Auto Scaling web tier.

## Architecture

- One VPC across two Availability Zones
- Two public subnets for the internet-facing Application Load Balancer
- Two private subnets for EC2 web instances
- One NAT Gateway in a public subnet for private instance package installation and updates
- Auto Scaling Group in private subnets with minimum 1, desired 1, and maximum 4 instances
- Launch Template using the latest Amazon Linux 2023 AMI
- Apache HTTP Server installed by EC2 user data
- Instance security group allows inbound HTTP only from the ALB security group
- No inbound SSH rule
- Target tracking scaling policy keeps average ASG CPU utilization near 30%

## Files

- `templates/auto-scaling-web-tier.yaml`: CloudFormation template
- `scripts/validate-template.ps1`: local validation checks for the lab requirements
- `LAB_REVIEW_GUIDE.md`: detailed live review guide, demo script, troubleshooting notes, and likely reviewer questions

## Deploy With CloudFormation GitSync

1. Push this repository to GitHub.
2. In the AWS CloudFormation console, choose **Git sync** and connect the GitHub repository.
3. Select `templates/auto-scaling-web-tier.yaml` as the template file.
4. Create the stack and acknowledge IAM resource creation.
5. After deployment completes, copy the `AlbUrl` or `AlbDnsName` stack output.

The stack creates IAM resources for Systems Manager access, so CloudFormation requires the IAM acknowledgement.

## Validate Locally

Run the repository checks from PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\validate-template.ps1
```

Optional AWS-side syntax validation:

```powershell
aws cloudformation validate-template --template-body file://templates/auto-scaling-web-tier.yaml
```

## Live Review Demo

Open the application:

```powershell
curl http://<ALB-DNS-NAME>
```

Refresh the ALB URL in a browser to show the page displaying the serving instance ID, private IP, and Availability Zone.

Start CPU stress from the ALB endpoint:

```powershell
curl http://<ALB-DNS-NAME>/stress
```

The `/stress` endpoint starts a short CPU-bound workload on the private instance that receives the request. Repeat the request a few times if needed so the ASG average CPU metric exceeds 30%.

Watch scaling activity:

```powershell
aws autoscaling describe-scaling-activities --auto-scaling-group-name <ASG-NAME>
```

Watch targets join the ALB target group:

```powershell
aws elbv2 describe-target-health --target-group-arn <TARGET-GROUP-ARN>
```

After scale-out completes and new targets are healthy, refresh the ALB URL several times. The instance ID, private IP, or Availability Zone should change as the ALB distributes requests across healthy instances.

## Notes

- The NAT Gateway is intentionally single-gateway to satisfy the lab requirement while keeping cost lower. A production design that prioritizes AZ failure tolerance should use one NAT Gateway per Availability Zone with separate private route tables.
- The template uses HTTP for lab simplicity. Production internet-facing applications should add HTTPS with ACM certificates and redirect HTTP to HTTPS.
- Scale-in is handled by the target tracking policy after CPU utilization falls below the target for the required cooldown and evaluation periods.
