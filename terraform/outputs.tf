# Outputs for Zero Trust Network Architecture

# VPC Information
output "vpc_id" {
  description = "ID of the main VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the main VPC"
  value       = aws_vpc.main.cidr_block
}

# Subnet Information
output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "IDs of the private application subnets"
  value       = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  description = "IDs of the private database subnets"
  value       = aws_subnet.private_db[*].id
}

# Security Group Information
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "ID of the application security group"
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "ID of the database security group"
  value       = aws_security_group.db.id
}

output "bastion_security_group_id" {
  description = "ID of the bastion security group"
  value       = aws_security_group.bastion.id
}

output "vpc_endpoints_security_group_id" {
  description = "ID of the VPC endpoints security group"
  value       = aws_security_group.vpc_endpoints.id
}

# VPC Endpoints
output "s3_vpc_endpoint_id" {
  description = "ID of the S3 VPC endpoint"
  value       = aws_vpc_endpoint.s3.id
}

output "dynamodb_vpc_endpoint_id" {
  description = "ID of the DynamoDB VPC endpoint"
  value       = aws_vpc_endpoint.dynamodb.id
}

output "ec2_vpc_endpoint_id" {
  description = "ID of the EC2 VPC endpoint"
  value       = aws_vpc_endpoint.ec2.id
}

output "logs_vpc_endpoint_id" {
  description = "ID of the CloudWatch Logs VPC endpoint"
  value       = aws_vpc_endpoint.logs.id
}

output "monitoring_vpc_endpoint_id" {
  description = "ID of the CloudWatch Monitoring VPC endpoint"
  value       = aws_vpc_endpoint.monitoring.id
}

output "ssm_vpc_endpoint_id" {
  description = "ID of the SSM VPC endpoint"
  value       = aws_vpc_endpoint.ssm.id
}

output "kms_vpc_endpoint_id" {
  description = "ID of the KMS VPC endpoint"
  value       = aws_vpc_endpoint.kms.id
}

output "secretsmanager_vpc_endpoint_id" {
  description = "ID of the Secrets Manager VPC endpoint"
  value       = aws_vpc_endpoint.secretsmanager.id
}

# PrivateLink Service
output "internal_api_service_name" {
  description = "Service name for the internal API PrivateLink service"
  value       = aws_vpc_endpoint_service.internal_api.service_name
}

output "internal_nlb_dns_name" {
  description = "DNS name of the internal Network Load Balancer"
  value       = aws_lb.internal_nlb.dns_name
}

output "internal_nlb_zone_id" {
  description = "Zone ID of the internal Network Load Balancer"
  value       = aws_lb.internal_nlb.zone_id
}

# Cognito Information
output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
  sensitive   = true
}

output "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_user_pool_endpoint" {
  description = "Endpoint of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.endpoint
}

output "cognito_user_pool_domain" {
  description = "Domain of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.domain
}

output "cognito_user_pool_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.main.id
  sensitive   = true
}

output "cognito_user_pool_client_secret" {
  description = "Client secret of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.main.client_secret
  sensitive   = true
}

output "cognito_identity_pool_id" {
  description = "ID of the Cognito Identity Pool"
  value       = aws_cognito_identity_pool.main.id
}

# IAM Roles
output "authenticated_role_arn" {
  description = "ARN of the authenticated role"
  value       = aws_iam_role.authenticated.arn
}

output "admin_role_arn" {
  description = "ARN of the admin role"
  value       = aws_iam_role.admin_role.arn
}

output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "ec2_instance_role_arn" {
  description = "ARN of the EC2 instance role"
  value       = aws_iam_role.ec2_instance_role.arn
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

# KMS Information
output "kms_key_id" {
  description = "ID of the main KMS key"
  value       = aws_kms_key.main.id
  sensitive   = true
}

output "kms_key_arn" {
  description = "ARN of the main KMS key"
  value       = aws_kms_key.main.arn
}

output "kms_key_alias" {
  description = "Alias of the main KMS key"
  value       = aws_kms_alias.main.name
}

# Monitoring Information
output "flow_logs_log_group_name" {
  description = "Name of the VPC Flow Logs CloudWatch log group"
  value       = aws_cloudwatch_log_group.flow_logs.name
}

output "flow_logs_log_group_arn" {
  description = "ARN of the VPC Flow Logs CloudWatch log group"
  value       = aws_cloudwatch_log_group.flow_logs.arn
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : null
}

output "security_alerts_topic_arn" {
  description = "ARN of the security alerts SNS topic"
  value       = aws_sns_topic.security_alerts.arn
}

output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.zero_trust_dashboard.dashboard_name}"
}

# CloudTrail Information
output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = aws_cloudtrail.main.arn
}

output "cloudtrail_bucket_name" {
  description = "Name of the CloudTrail S3 bucket"
  value       = aws_s3_bucket.cloudtrail_bucket.bucket
}

# Network Information
output "availability_zones" {
  description = "Availability zones used"
  value       = slice(data.aws_availability_zones.available.names, 0, var.availability_zones_count)
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "Public IP addresses of the NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

# DNS Information
output "private_dns_zone_id" {
  description = "ID of the private DNS zone"
  value       = aws_route53_zone.internal.zone_id
}

output "private_dns_zone_name" {
  description = "Name of the private DNS zone"
  value       = aws_route53_zone.internal.name
}

# Database subnet group
output "db_subnet_group_name" {
  description = "Name of the database subnet group"
  value       = aws_db_subnet_group.main.name
}

# Config Information (if enabled)
output "config_bucket_name" {
  description = "Name of the Config S3 bucket"
  value       = var.enable_guardduty ? aws_s3_bucket.config_bucket[0].bucket : null
}

output "config_recorder_name" {
  description = "Name of the Config recorder"
  value       = var.enable_guardduty ? aws_config_configuration_recorder.main[0].name : null
}

# Account and Region Information
output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = data.aws_region.current.name
}

# Project Information
output "project_name" {
  description = "Project name"
  value       = var.project_name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

# Application Infrastructure Information
output "ecr_repository_url" {
  description = "URL of the ECR repository for the application"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.app.zone_id
}

output "alb_url" {
  description = "URL of the Application Load Balancer"
  value       = "http://${aws_lb.app.dns_name}"
}

output "service_discovery_namespace" {
  description = "Service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.main.name
}

# Summary Information
output "architecture_summary" {
  description = "Zero Trust Architecture deployment summary"
  value = {
    vpc_id               = aws_vpc.main.id
    vpc_cidr             = aws_vpc.main.cidr_block
    availability_zones   = slice(data.aws_availability_zones.available.names, 0, var.availability_zones_count)
    public_subnets       = length(aws_subnet.public)
    private_app_subnets  = length(aws_subnet.private_app)
    private_db_subnets   = length(aws_subnet.private_db)
    security_groups      = 5
    vpc_endpoints        = 10
    monitoring_enabled   = var.enable_flow_logs && var.enable_guardduty
    cognito_enabled      = true
    encryption_enabled   = true
    network_segmentation = "Multi-tier with NACLs"
    application_deployed = true
    application_url      = "http://${aws_lb.app.dns_name}"
    zero_trust_features = [
      "Micro-segmentation",
      "PrivateLink connectivity",
      "Identity-based access",
      "Continuous monitoring",
      "Encrypted communication",
      "Least privilege access"
    ]
  }
}
