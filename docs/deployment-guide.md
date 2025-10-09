# Zero Trust Architecture - Deployment Guide

## Prerequisites

Before deploying the Zero Trust architecture, ensure you have the following:

### Required Tools
- **Terraform** >= 1.0 ([Installation Guide](https://developer.hashicorp.com/terraform/downloads))
- **AWS CLI** >= 2.0 ([Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- **Git** for cloning the repository

### AWS Requirements
- **AWS Account** with appropriate permissions
- **IAM User/Role** with the following permissions:
  - VPC management (EC2, VPC, Route53)
  - IAM role and policy management
  - Cognito management
  - CloudWatch and GuardDuty access
  - S3 and KMS access
- **AWS CLI configured** with credentials

### Recommended AWS Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "vpc:*",
        "iam:*",
        "cognito-idp:*",
        "cognito-identity:*",
        "logs:*",
        "cloudwatch:*",
        "guardduty:*",
        "config:*",
        "s3:*",
        "kms:*",
        "sns:*",
        "cloudtrail:*",
        "route53:*",
        "secretsmanager:*",
        "ssm:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/your-org/zero-trust-aws-architecture.git
cd zero-trust-aws-architecture
```

### 2. Configure Variables
```bash
# Copy the example variables file
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Edit with your specific values
vim terraform/terraform.tfvars
```

### 3. Deploy Architecture
```bash
# Run the automated deployment script
./scripts/deploy.sh

# Or manually deploy
cd terraform
terraform init
terraform plan
terraform apply
```

## Detailed Deployment Steps

### Step 1: Environment Setup

#### Configure AWS CLI
```bash
# Configure AWS credentials
aws configure

# Verify configuration
aws sts get-caller-identity
```

#### Set Environment Variables (Optional)
```bash
export AWS_REGION="us-west-2"
export PROJECT_NAME="zero-trust-arch"
export ENVIRONMENT="dev"
```

### Step 2: Customize Configuration

Edit the `terraform/terraform.tfvars` file with your specific requirements:

```hcl
# Basic Configuration
aws_region     = "us-west-2"
environment    = "production"  # dev, staging, production
project_name   = "company-zero-trust"
project_owner  = "security-team"

# Network Configuration
vpc_cidr                    = "10.0.0.0/16"
availability_zones_count    = 3  # For production, use 3 AZs
public_subnet_cidrs        = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_app_subnet_cidrs   = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
private_db_subnet_cidrs    = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]

# Security Configuration
allowed_cidr_blocks = ["YOUR_OFFICE_IP/32", "YOUR_VPN_RANGE/24"]  # IMPORTANT: Restrict this
db_port            = 5432
app_port           = 8080

# Monitoring Configuration
enable_flow_logs           = true
enable_guardduty          = true
flow_logs_retention_days  = 90  # For compliance, consider 90+ days

# Cognito Configuration
cognito_user_pool_name     = "company-zero-trust-users"
cognito_identity_pool_name = "company-zero-trust-identities"

# Tags
common_tags = {
  Architecture = "Zero-Trust"
  Security     = "High"
  Compliance   = "SOC2"
  CostCenter   = "Security"
  Owner        = "security-team@company.com"
  Project      = "Zero-Trust-Implementation"
  Environment  = "production"
}
```

### Step 3: Validate Configuration

#### Check Terraform Configuration
```bash
cd terraform

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt

# Check for security issues (if using tfsec)
tfsec .
```

#### Review Planned Changes
```bash
# Generate execution plan
terraform plan -out=tfplan

# Review the plan carefully
# Ensure no unexpected resources will be created/destroyed
```

### Step 4: Deploy Infrastructure

#### Automated Deployment
```bash
# Use the provided deployment script
./scripts/deploy.sh

# Or deploy specific components
./scripts/deploy.sh plan    # Plan only
./scripts/deploy.sh apply   # Apply only
```

#### Manual Deployment
```bash
cd terraform

# Apply the configuration
terraform apply tfplan

# Monitor the deployment process
# This typically takes 15-20 minutes
```

### Step 5: Post-Deployment Configuration

#### Verify Deployment
```bash
# Check key outputs
terraform output vpc_id
terraform output cognito_user_pool_arn
terraform output cloudwatch_dashboard_url

# Verify VPC configuration
aws ec2 describe-vpcs --vpc-ids $(terraform output -raw vpc_id)

# Check security groups
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"
```

#### Configure SNS Notifications
```bash
# Subscribe to security alerts
aws sns subscribe \
  --topic-arn $(terraform output -raw security_alerts_topic_arn) \
  --protocol email \
  --notification-endpoint security-team@company.com
```

#### Create Cognito Users
```bash
# Create admin user
aws cognito-idp admin-create-user \
  --user-pool-id $(terraform output -raw cognito_user_pool_id) \
  --username admin \
  --user-attributes Name=email,Value=admin@company.com \
  --temporary-password TempPassword123! \
  --message-action SUPPRESS

# Set permanent password
aws cognito-idp admin-set-user-password \
  --user-pool-id $(terraform output -raw cognito_user_pool_id) \
  --username admin \
  --password YourSecurePassword123! \
  --permanent
```

## Environment-Specific Configurations

### Development Environment
```hcl
# terraform/environments/dev.tfvars
environment                = "dev"
availability_zones_count   = 2
enable_guardduty          = false  # Save costs in dev
flow_logs_retention_days  = 7      # Shorter retention
```

### Production Environment
```hcl
# terraform/environments/prod.tfvars
environment                = "production"
availability_zones_count   = 3     # High availability
enable_guardduty          = true   # Full security monitoring
flow_logs_retention_days  = 90     # Compliance requirements
```

### Deploy Specific Environment
```bash
# Deploy development environment
terraform apply -var-file="environments/dev.tfvars"

# Deploy production environment
terraform apply -var-file="environments/prod.tfvars"
```

## Monitoring and Verification

### Check Deployment Status
```bash
# View CloudWatch Dashboard
aws cloudwatch get-dashboard \
  --dashboard-name $(terraform output -raw project_name)-$(terraform output -raw environment)-zero-trust-dashboard

# Check GuardDuty status
aws guardduty get-detector --detector-id $(terraform output -raw guardduty_detector_id)

# Verify VPC Flow Logs
aws logs describe-log-groups --log-group-name-prefix "/aws/vpc/flowlogs"
```

### Test Network Connectivity
```bash
# Test VPC endpoints
aws s3 ls --region $(terraform output -raw aws_region) --endpoint-url https://s3.$(terraform output -raw aws_region).amazonaws.com

# Verify security group rules
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$(terraform output -raw app_security_group_id)"
```

### Monitor Security Metrics
```bash
# Check for GuardDuty findings
aws guardduty list-findings --detector-id $(terraform output -raw guardduty_detector_id)

# Review Config compliance
aws configservice get-compliance-summary-by-config-rule
```

## Troubleshooting

### Common Deployment Issues

#### Issue 1: Terraform State Lock
```bash
# Error: acquiring the state lock
terraform force-unlock <LOCK_ID>

# Better: Use remote state with DynamoDB locking
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "zero-trust/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-state-lock"
  }
}
```

#### Issue 2: AWS API Rate Limiting
```bash
# Add delays between resource creation
resource "time_sleep" "wait_30_seconds" {
  depends_on = [aws_vpc.main]
  create_duration = "30s"
}
```

#### Issue 3: VPC Endpoint DNS Resolution
```bash
# Ensure private DNS is enabled
aws ec2 modify-vpc-endpoint \
  --vpc-endpoint-id $(terraform output -raw s3_vpc_endpoint_id) \
  --private-dns-enabled
```

### Validation Commands

#### Network Connectivity Tests
```bash
# Test from EC2 instance in private subnet
# SSH via bastion host, then:
curl -I https://s3.amazonaws.com  # Should resolve to VPC endpoint
dig s3.amazonaws.com              # Should return private IP

# Test database connectivity
telnet <rds-endpoint> 5432
```

#### Security Validation
```bash
# Verify security group rules are restrictive
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)" \
  --query 'SecurityGroups[*].{GroupId:GroupId,Rules:IpPermissions}'

# Check NACL rules
aws ec2 describe-network-acls \
  --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"
```

## Backup and Disaster Recovery

### State Backup
```bash
# Backup Terraform state
aws s3 cp terraform.tfstate s3://your-backup-bucket/zero-trust-backups/

# Create state snapshot
terraform show -json > state-snapshot-$(date +%Y%m%d).json
```

### Configuration Backup
```bash
# Backup all configuration
tar -czf zero-trust-backup-$(date +%Y%m%d).tar.gz \
  terraform/ \
  docs/ \
  scripts/
```

### Disaster Recovery
```bash
# Restore from backup
terraform init
terraform plan -detailed-exitcode

# If drift detected, apply to restore
terraform apply -auto-approve
```

## Security Considerations

### Production Hardening Checklist

- [ ] **Restrict CIDR blocks** in `allowed_cidr_blocks`
- [ ] **Enable GuardDuty** for threat detection
- [ ] **Configure SNS alerts** for security events
- [ ] **Enable CloudTrail** for API auditing
- [ ] **Use KMS encryption** for all data at rest
- [ ] **Enable MFA** for Cognito users
- [ ] **Regular security reviews** of IAM policies
- [ ] **Monitor VPC Flow Logs** for anomalies

### Compliance Requirements

#### SOC 2 Compliance
- Enable all monitoring components
- Set log retention to 1 year minimum
- Implement change control processes
- Regular access reviews

#### PCI DSS Compliance
- Ensure network segmentation
- Enable encryption everywhere
- Implement strong access controls
- Regular vulnerability assessments

## Cost Optimization

### Monthly Cost Breakdown
- **VPC Endpoints**: ~$72/month (10 interface endpoints)
- **NAT Gateways**: ~$135/month (3 gateways for prod)
- **GuardDuty**: ~$4.50/month + usage
- **CloudTrail**: ~$2/month + S3 costs
- **Flow Logs**: Variable based on traffic
- **KMS**: ~$1/month per key

### Cost Optimization Tips
1. **Use Gateway Endpoints** (S3, DynamoDB) instead of Interface Endpoints where possible
2. **Optimize NAT Gateway usage** with VPC Endpoints for AWS services
3. **Adjust Flow Logs retention** based on compliance requirements
4. **Use S3 Intelligent Tiering** for CloudTrail and Flow Logs storage
5. **Monitor and right-size** resources regularly

## Next Steps

After successful deployment:

1. **[Configure Applications](./application-integration.md)**: Deploy your applications to the private subnets
2. **[Set up Monitoring](./monitoring-guide.md)**: Configure alerts and dashboards
3. **[Security Testing](./security-testing.md)**: Perform penetration testing
4. **[Operations Guide](./operations-guide.md)**: Day-to-day management procedures

## Support and Documentation

- **Architecture Documentation**: [docs/](../docs/)
- **Terraform Code**: [terraform/](../terraform/)
- **Deployment Scripts**: [scripts/](../scripts/)
- **Issue Tracking**: Create GitHub issues for problems
- **Security Alerts**: security-team@company.com

---

**Important**: This deployment creates AWS resources that incur costs. Review the cost breakdown and ensure you understand the pricing before deploying to production.