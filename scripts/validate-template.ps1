param(
    [string]$TemplatePath = "templates/auto-scaling-web-tier.yaml"
)

$ErrorActionPreference = "Stop"

function Assert-Contains {
    param(
        [string]$Content,
        [string]$Pattern,
        [string]$Message
    )

    if ($Content -notmatch $Pattern) {
        throw $Message
    }
}

if (-not (Test-Path -LiteralPath $TemplatePath)) {
    throw "Template not found at $TemplatePath"
}

$template = Get-Content -LiteralPath $TemplatePath -Raw

Assert-Contains $template 'AWS::EC2::VPC' "VPC resource is required."
Assert-Contains $template 'AWS::EC2::InternetGateway' "Internet gateway is required."
Assert-Contains $template 'AWS::EC2::NatGateway' "Regional NAT Gateway is required."
Assert-Contains $template 'AWS::ElasticLoadBalancingV2::LoadBalancer' "Application Load Balancer is required."
Assert-Contains $template 'Scheme:\s+internet-facing' "ALB must be internet-facing."
Assert-Contains $template 'AWS::ElasticLoadBalancingV2::TargetGroup' "Target group is required."
Assert-Contains $template 'AWS::ElasticLoadBalancingV2::Listener' "ALB listener is required."
Assert-Contains $template 'AWS::AutoScaling::AutoScalingGroup' "Auto Scaling Group is required."
Assert-Contains $template 'MinSize:\s+["'']?1["'']?' "ASG minimum capacity must be 1."
Assert-Contains $template 'DesiredCapacity:\s+["'']?1["'']?' "ASG desired capacity must be 1."
Assert-Contains $template 'MaxSize:\s+["'']?4["'']?' "ASG maximum capacity must be 4."
Assert-Contains $template 'AWS::EC2::LaunchTemplate' "Launch Template is required."
Assert-Contains $template 'CPUUtilization' "CPU-based scaling metric is required."
Assert-Contains $template 'TargetValue:\s+30(\.0)?' "Scale-out CPU target must be 30 percent."
Assert-Contains $template 'NoIngressSecurityGroup' "Instance security group must avoid direct public inbound access."
Assert-Contains $template 'yum install -y httpd' "User data must install Apache HTTP Server."
Assert-Contains $template 'INSTANCE_ID' "Application must display instance-specific identity."
Assert-Contains $template '/stress' "Application must include a CPU stress endpoint for demonstrations."
Assert-Contains $template 'Outputs:' "Template must expose useful outputs."
Assert-Contains $template 'AlbDnsName' "ALB DNS output is required."

Write-Host "Template validation checks passed."
