# AWS PrivateLink and VPC Endpoints for Zero Trust Architecture

# VPC Endpoint for S3 (Gateway endpoint - no additional cost)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private_app[*].id,
    aws_route_table.private_db[*].id
  )

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::*"
        ]
        Condition = {
          StringEquals = {
            "aws:PrincipalVpc" = aws_vpc.main.id
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-s3-endpoint"
    Type    = "VPC-Endpoint"
    Service = "S3"
  })
}

# VPC Endpoint for DynamoDB (Gateway endpoint - no additional cost)
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private_app[*].id,
    aws_route_table.private_db[*].id
  )

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalVpc" = aws_vpc.main.id
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-dynamodb-endpoint"
    Type    = "VPC-Endpoint"
    Service = "DynamoDB"
  })
}

# VPC Endpoint for EC2 (Interface endpoint)
resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:DescribeSnapshots",
          "ec2:DescribeVolumes"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalVpc" = aws_vpc.main.id
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-ec2-endpoint"
    Type    = "VPC-Endpoint"
    Service = "EC2"
  })
}

# VPC Endpoint for CloudWatch Logs
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalVpc" = aws_vpc.main.id
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-logs-endpoint"
    Type    = "VPC-Endpoint"
    Service = "CloudWatch-Logs"
  })
}

# VPC Endpoint for CloudWatch Monitoring
resource "aws_vpc_endpoint" "monitoring" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.monitoring"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalVpc" = aws_vpc.main.id
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-monitoring-endpoint"
    Type    = "VPC-Endpoint"
    Service = "CloudWatch-Monitoring"
  })
}

# VPC Endpoint for Systems Manager (SSM)
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:PutParameter"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalVpc" = aws_vpc.main.id
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-ssm-endpoint"
    Type    = "VPC-Endpoint"
    Service = "Systems-Manager"
  })
}

# VPC Endpoint for ECS (if using containers)
resource "aws_vpc_endpoint" "ecs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "ecs:CreateCluster",
          "ecs:DescribeClusters",
          "ecs:RegisterTaskDefinition",
          "ecs:RunTask",
          "ecs:StopTask",
          "ecs:DescribeTasks"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalVpc" = aws_vpc.main.id
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-ecs-endpoint"
    Type    = "VPC-Endpoint"
    Service = "ECS"
  })
}

# VPC Endpoint for ECR API (if using containers)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalVpc" = aws_vpc.main.id
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-ecr-api-endpoint"
    Type    = "VPC-Endpoint"
    Service = "ECR-API"
  })
}

# VPC Endpoint for ECR DKR (Docker registry)
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalVpc" = aws_vpc.main.id
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-ecr-dkr-endpoint"
    Type    = "VPC-Endpoint"
    Service = "ECR-DKR"
  })
}

# VPC Endpoint for Secrets Manager
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalVpc" = aws_vpc.main.id
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-secretsmanager-endpoint"
    Type    = "VPC-Endpoint"
    Service = "Secrets-Manager"
  })
}

# VPC Endpoint for KMS
resource "aws_vpc_endpoint" "kms" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalVpc" = aws_vpc.main.id
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-kms-endpoint"
    Type    = "VPC-Endpoint"
    Service = "KMS"
  })
}

# Private DNS Zone for internal service discovery (optional)
resource "aws_route53_zone" "internal" {
  name = "${var.project_name}-${var.environment}.internal"

  vpc {
    vpc_id = aws_vpc.main.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-internal-dns"
    Type = "Private-DNS-Zone"
  })
}

# Example PrivateLink service for exposing internal API
resource "aws_vpc_endpoint_service" "internal_api" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.internal_nlb.arn]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-internal-api-service"
    Type = "PrivateLink-Service"
  })
}

# Network Load Balancer for internal API (PrivateLink)
resource "aws_lb" "internal_nlb" {
  name               = "${var.project_name}-${var.environment}-internal-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = aws_subnet.private_app[*].id

  enable_deletion_protection = false

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-internal-nlb"
    Type    = "Network-Load-Balancer"
    Purpose = "PrivateLink"
  })
}

# Target group for internal API
resource "aws_lb_target_group" "internal_api" {
  name     = "${var.project_name}-${var.environment}-api-tg"
  port     = var.app_port
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-internal-api-tg"
    Type = "Target-Group"
  })
}

# Listener for internal NLB
resource "aws_lb_listener" "internal_api" {
  load_balancer_arn = aws_lb.internal_nlb.arn
  port              = var.app_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal_api.arn
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-internal-api-listener"
    Type = "NLB-Listener"
  })
}