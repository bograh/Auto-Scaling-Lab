# Auto Scaling Lab Review Guide

Use this guide to prepare for the live lab review and to explain the design decisions clearly while demonstrating the deployed stack.

## 1. Review Objective

The goal of this lab is to prove that a public-facing web application can remain available during traffic spikes while keeping normal operating cost low.

The deployed solution uses:

- An internet-facing Application Load Balancer as the only public application endpoint
- Private EC2 instances with no direct public inbound access
- An Auto Scaling Group that starts with one instance and can scale out to four
- CPU-based target tracking scaling at 30% average ASG CPU utilization
- A NAT Gateway so private instances can install packages and receive updates
- CloudFormation as Infrastructure as Code
- CloudFormation GitSync for repeatable deployment from GitHub

## 2. Architecture Summary

Traffic flow:

1. User sends an HTTP request to the ALB DNS name.
2. The internet-facing ALB receives the request in public subnets.
3. The ALB forwards traffic to healthy EC2 targets in private subnets.
4. EC2 instances serve the Apache web page.
5. The page displays the instance ID, Availability Zone, and private IP address.
6. Auto Scaling monitors average CPU utilization across the ASG.
7. When average CPU exceeds 30%, the ASG launches more instances.
8. New instances automatically register with the ALB target group.

Key security point:

The EC2 instances do not have public IP addresses and do not allow inbound SSH. Their security group only allows HTTP from the ALB security group.

## 3. Deployed Resources To Highlight

During the review, point out these resources in the AWS console or CloudFormation template:

- VPC: custom VPC for the lab
- Public subnets: used by the ALB
- Private subnets: used by EC2 web instances
- Internet Gateway: allows public ALB connectivity
- NAT Gateway: allows private instances to reach the internet for package installation
- Route tables: public route to IGW, private route to NAT Gateway
- ALB: internet-facing public endpoint
- Target group: receives instances from the ASG
- Launch Template: defines AMI, instance type, security group, IAM profile, and user data
- Auto Scaling Group: min 1, desired 1, max 4
- Scaling policy: target tracking policy using average CPU utilization at 30%
- Security groups: ALB allows public HTTP; instance SG allows HTTP only from ALB

## 4. Pre-Review Checklist

Complete these before the live review:

- GitHub repository is public and contains the CloudFormation template.
- CloudFormation stack is deployed successfully through GitSync.
- Stack status is `CREATE_COMPLETE` or `UPDATE_COMPLETE`.
- `AlbUrl`, `AlbDnsName`, `AutoScalingGroupName`, and `TargetGroupArn` outputs are available.
- The ALB URL loads successfully in a browser.
- The initial target is healthy in the target group.
- You have AWS console tabs ready for:
  - CloudFormation stack outputs
  - EC2 Target Groups
  - Auto Scaling Group activity
  - CloudWatch metrics for ASG CPU utilization
- You have terminal commands prepared for `curl`, scaling activity, and target health checks.

## 5. Live Demonstration Flow

### Step 1: Show Infrastructure as Code

Open the GitHub repository and show:

- `templates/auto-scaling-web-tier.yaml`
- `README.md`
- `LAB_REVIEW_GUIDE.md`

Explain:

The infrastructure is not manually built. It is defined in CloudFormation and deployed through GitSync, which improves repeatability, auditability, and consistency between deployments.

### Step 2: Show CloudFormation GitSync Deployment

In the CloudFormation console, show:

- Stack source is connected to the GitHub repository
- Stack deployment status is complete
- Outputs include the ALB URL and ASG name

Say:

CloudFormation GitSync keeps the stack aligned with the GitHub repository. Template changes can be reviewed in source control and then applied consistently through CloudFormation.

### Step 3: Access The Application Through The ALB

Open:

```text
http://<ALB-DNS-NAME>
```

Expected result:

- The web page loads.
- It displays the instance ID.
- It displays the private IP address.
- It displays the Availability Zone.

Explain:

Users only know the ALB DNS name. They do not know or access the backend instances directly.

### Step 4: Prove Backend Instances Are Private

In the EC2 console, show the running web instance.

Point out:

- It is in a private subnet.
- It does not have a public IPv4 address.
- There is no SSH inbound rule.
- Its security group allows HTTP only from the ALB security group.

Explain:

This satisfies the requirement that backend servers are not directly exposed to the public internet.

### Step 5: Show Initial Target Group Health

Open the ALB target group and show registered targets.

Expected result:

- One target is registered at the start.
- Target health is `healthy`.

CLI option:

```powershell
aws elbv2 describe-target-health --target-group-arn <TARGET-GROUP-ARN>
```

Explain:

The ASG automatically registers instances with the target group. The ALB only forwards traffic to healthy targets.

### Step 6: Trigger CPU Stress

Open or call:

```text
http://<ALB-DNS-NAME>/stress
```

CLI option:

```powershell
curl http://<ALB-DNS-NAME>/stress
```

Expected result:

The endpoint starts a temporary CPU workload on the instance that receives the request.

Repeat the request a few times if needed:

```powershell
curl http://<ALB-DNS-NAME>/stress
curl http://<ALB-DNS-NAME>/stress
curl http://<ALB-DNS-NAME>/stress
```

Explain:

The stress endpoint is included only for demonstration. It helps create enough CPU load to trigger the scaling policy during the review.

### Step 7: Observe Scale-Out

In the Auto Scaling Group console, open:

- Activity tab
- Instance management tab
- CloudWatch monitoring tab

CLI option:

```powershell
aws autoscaling describe-scaling-activities --auto-scaling-group-name <ASG-NAME>
```

Expected result:

- CPU utilization rises above 30%.
- Auto Scaling launches one or more new instances.
- New instances move through pending lifecycle states.
- New instances pass health checks.
- New instances appear in the ALB target group.

Explain:

The target tracking policy attempts to keep average ASG CPU utilization near 30%. When demand increases, the ASG adds capacity automatically.

### Step 8: Show New Instances Joining The Target Group

Open the target group health page again.

Expected result:

- Additional instances are registered.
- After initialization and health checks, they become healthy.

CLI option:

```powershell
aws elbv2 describe-target-health --target-group-arn <TARGET-GROUP-ARN>
```

Explain:

No manual registration is required. The ASG and target group integration handles this automatically.

### Step 9: Demonstrate Load Distribution

Refresh the ALB URL several times.

Expected result:

- The displayed instance ID, private IP, or Availability Zone changes.

Explain:

The ALB distributes requests across healthy targets using round-robin behavior. The instance-specific page proves that different backend servers are serving traffic.

### Step 10: Explain Scale-In

After the CPU workload ends, CPU utilization decreases.

Explain:

Target tracking policies also support scale-in. Once load falls and CloudWatch evaluation periods are satisfied, Auto Scaling can reduce capacity back toward the desired baseline while respecting the minimum size of one instance.

## 6. Key Design Decisions

### Why Use An Application Load Balancer?

An ALB provides a single public endpoint and distributes HTTP traffic across multiple backend instances. It also performs health checks so unhealthy instances do not receive traffic.

### Why Put EC2 Instances In Private Subnets?

Private subnets reduce attack surface. Users access the application through the ALB, not directly through EC2 public IP addresses.

### Why Use A NAT Gateway?

Instances in private subnets need outbound internet access to install Apache and receive package updates. The NAT Gateway allows outbound internet access without exposing private instances to inbound internet traffic.

### Why Use Auto Scaling?

Auto Scaling adjusts compute capacity automatically. It adds instances during high demand and can remove instances when demand drops, improving availability and cost efficiency.

### Why Use CPU Utilization At 30%?

The lab requires scale-out when average CPU utilization exceeds 30%. A low threshold also makes scaling easier to demonstrate during a live review.

### Why Use A Launch Template?

Launch Templates define repeatable instance configuration, including AMI, instance type, security groups, IAM profile, metadata options, and user data.

### Why Use CloudFormation GitSync?

GitSync connects CloudFormation deployment to a Git repository. This supports auditability, version control, repeatable deployments, and reviewable infrastructure changes.

## 7. Possible Reviewer Questions And Answers

### Q1. Why is the ALB placed in public subnets?

The ALB is internet-facing, so it must be reachable from the internet. Public subnets have a route to the Internet Gateway, which allows users to access the ALB DNS name.

### Q2. Why are the EC2 instances placed in private subnets?

The instances should not be directly exposed to the public internet. They only receive traffic from the ALB security group.

### Q3. Can users connect directly to the EC2 instances?

No. The instances have no public inbound access and no SSH ingress rule. Users access the application only through the ALB endpoint.

### Q4. Why is there no SSH access?

SSH is not required for this lab and would increase the attack surface. Operational access can be handled through AWS Systems Manager Session Manager because the instance role includes `AmazonSSMManagedInstanceCore`.

### Q5. Why does the template use a NAT Gateway?

The private instances need outbound internet access during bootstrapping to update packages and install Apache. The NAT Gateway allows outbound internet access while blocking unsolicited inbound internet access.

### Q6. Is one NAT Gateway highly available?

One NAT Gateway is regional as a managed AWS service, but it is deployed into a single subnet and Availability Zone. This lab uses one NAT Gateway for cost control and to meet the stated requirement. A production design requiring stronger AZ fault tolerance should deploy one NAT Gateway per AZ with separate private route tables.

### Q7. What happens if the NAT Gateway fails?

Existing web traffic through the ALB can continue if the instances are already configured, but private instances may lose outbound internet access for updates or package installation. New instance bootstrapping could fail if it depends on internet package repositories.

### Q8. How does the ALB know which instances to send traffic to?

The ASG is attached to the target group. When the ASG launches instances, it registers them with the target group. The ALB forwards traffic only to healthy registered targets.

### Q9. How do you prove traffic is served by multiple instances?

The web page displays the instance ID, private IP, and Availability Zone. After scaling out, refreshing the ALB URL should show different values as requests are sent to different healthy targets.

### Q10. What load balancing algorithm is used?

The target group is configured with `load_balancing.algorithm.type` set to `round_robin`, which distributes requests across healthy targets.

### Q11. What triggers scale-out?

The target tracking scaling policy monitors average CPU utilization across the Auto Scaling Group. When average CPU rises above the 30% target, the ASG launches additional instances, up to the maximum size of four.

### Q12. What is the ASG minimum, desired, and maximum capacity?

Minimum capacity is 1, desired capacity is 1, and maximum capacity is 4.

### Q13. Why is desired capacity set to 1?

It keeps normal operating cost low while still ensuring at least one instance is available. Additional instances are launched only when demand increases.

### Q14. Does the design support high availability if only one instance is running?

The network and ASG span two Availability Zones, and the ASG can replace failed instances. However, with desired capacity of one, the application has a smaller steady-state availability posture than running at least two instances. The value is set to one because the lab explicitly requires desired capacity of one and emphasizes cost minimization.

### Q15. What happens if the only running instance fails?

The ALB health check detects the failure, and the ASG replaces the unhealthy instance. During replacement, there may be a short period of reduced or unavailable service because the lab baseline desired capacity is one.

### Q16. Why use target tracking instead of a simple scaling policy?

Target tracking is easier to operate because it automatically adjusts capacity to maintain a target metric value. In this lab, the target is 30% average CPU utilization.

### Q17. Does the policy also scale in?

Yes. Target tracking can scale in when CPU drops below the target and the required evaluation/cooldown conditions are met, while respecting the ASG minimum capacity of one.

### Q18. How long does scale-out take?

Scale-out depends on CloudWatch metric evaluation, instance launch time, user data execution, and ALB health checks. It can take several minutes before new instances are healthy and serving traffic.

### Q19. Why might the scale-out demo not happen immediately?

CloudWatch metrics and Auto Scaling policies are not instant. The CPU load must be high enough for the metric evaluation period, and the ASG needs time to launch, initialize, and register new instances.

### Q20. Why use Amazon Linux?

The lab requires an Amazon Linux AMI. The template uses the latest Amazon Linux 2023 AMI through the AWS Systems Manager public parameter.

### Q21. What does the EC2 user data do?

It updates packages, installs Apache, creates the web page, adds instance-specific metadata to the page, creates the `/stress` endpoint, and starts Apache.

### Q22. How does the page get the instance ID?

The user data script calls the EC2 Instance Metadata Service using IMDSv2 and writes the instance ID, Availability Zone, and private IP into the HTML page.

### Q23. Why enforce IMDSv2?

IMDSv2 improves instance metadata security by requiring a session token before metadata can be retrieved.

### Q24. What security groups are used?

The ALB security group allows inbound HTTP from the internet. The instance security group allows inbound HTTP only from the ALB security group and allows outbound traffic for updates and package installation.

### Q25. Why is HTTP used instead of HTTPS?

HTTP keeps the lab simple and avoids certificate setup. In production, the ALB should use HTTPS with an ACM certificate and should redirect HTTP to HTTPS.

### Q26. How does GitSync improve the deployment?

GitSync connects the CloudFormation stack to the GitHub repository. Infrastructure changes are tracked in version control and can be deployed consistently from the repository.

### Q27. What makes this Infrastructure as Code?

All core infrastructure resources are defined declaratively in the CloudFormation template, including networking, routing, security, load balancing, launch template, Auto Scaling, and scaling policies.

### Q28. Where are the private instances allowed to send outbound traffic?

The instance security group allows outbound traffic, and the private route table sends internet-bound traffic through the NAT Gateway.

### Q29. What is the purpose of the target group health check?

The health check confirms that instances can serve the application before the ALB sends them user traffic.

### Q30. What would you improve for production?

Production improvements would include HTTPS, AWS WAF, one NAT Gateway per AZ, desired capacity of at least two, access logs, tighter egress controls, alarms, dashboards, AMI baking or a private artifact repository, and possibly blue/green deployment.

## 8. Troubleshooting During Review

### Page Does Not Load

Check:

- Stack completed successfully.
- ALB is internet-facing.
- ALB listener exists on port 80.
- Target group has a healthy target.
- Instance user data completed.
- Instance security group allows HTTP from the ALB security group.

Commands:

```powershell
aws elbv2 describe-target-health --target-group-arn <TARGET-GROUP-ARN>
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names <ASG-NAME>
```

### Target Is Unhealthy

Check:

- Apache is installed and running.
- User data completed successfully.
- Health check path is `/`.
- Instance security group allows port 80 from the ALB security group.
- Private subnet route to the NAT Gateway works for package installation.

If using Systems Manager:

```powershell
aws ssm start-session --target <INSTANCE-ID>
```

Then check:

```bash
sudo systemctl status httpd
sudo tail -n 100 /var/log/cloud-init-output.log
curl -I http://localhost/
```

### Scale-Out Does Not Trigger

Check:

- `/stress` was called enough times.
- CloudWatch CPU metric has had time to update.
- ASG maximum capacity has not already been reached.
- Scaling policy exists and targets 30% CPU.
- Instance type has enough CPU behavior to show utilization clearly.

Useful command:

```powershell
aws autoscaling describe-scaling-activities --auto-scaling-group-name <ASG-NAME>
```

### New Instances Do Not Become Healthy

Check:

- NAT Gateway and private routes are working.
- User data can install Apache.
- ALB health check path is correct.
- Security group rules allow ALB-to-instance HTTP.
- Launch Template references the correct AMI and instance profile.

### Refreshing Does Not Show Different Instances

Possible causes:

- Only one target is healthy.
- New instances are still initializing.
- Browser connection reuse may make changes less obvious.

Try:

```powershell
curl http://<ALB-DNS-NAME>
curl http://<ALB-DNS-NAME>
curl http://<ALB-DNS-NAME>
```

Or open the page in a private browser window and refresh after all targets are healthy.

## 9. Short Presentation Script

Use this concise explanation if asked to summarize the project:

This lab deploys a highly available web tier using CloudFormation and GitSync. Users access the application through an internet-facing Application Load Balancer in public subnets. The backend EC2 instances run in private subnets with no direct SSH or public inbound access. A NAT Gateway allows the private instances to install Apache and updates during initialization. The Auto Scaling Group starts with one instance and can scale to four based on average CPU utilization. The application displays the serving instance ID, private IP, and Availability Zone, which lets us prove that traffic is distributed across multiple instances after scale-out.

## 10. Commands To Keep Ready

Replace placeholders before the review.

```powershell
$AlbDnsName = "<ALB-DNS-NAME>"
$AsgName = "<ASG-NAME>"
$TargetGroupArn = "<TARGET-GROUP-ARN>"

curl "http://$AlbDnsName"
curl "http://$AlbDnsName/stress"

aws autoscaling describe-scaling-activities --auto-scaling-group-name $AsgName
aws elbv2 describe-target-health --target-group-arn $TargetGroupArn
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $AsgName
```

