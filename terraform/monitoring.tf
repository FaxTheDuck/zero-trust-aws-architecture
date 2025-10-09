# Monitoring and Threat Detection for Zero Trust Architecture

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flowlogs/${var.project_name}-${var.environment}"
  retention_in_days = var.flow_logs_retention_days
  kms_key_id        = aws_kms_key.main.arn

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-vpc-flowlogs"
    Type    = "CloudWatch-LogGroup"
    Purpose = "VPC-FlowLogs"
  })
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_logs_role" {
  name = "${var.project_name}-${var.environment}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-flow-logs-role"
    Type    = "IAM-Role"
    Service = "VPC-FlowLogs"
  })
}

# IAM Policy for VPC Flow Logs
resource "aws_iam_policy" "flow_logs_policy" {
  name        = "${var.project_name}-${var.environment}-flow-logs-policy"
  description = "IAM policy for VPC Flow Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.main.arn
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-flow-logs-policy"
    Type = "IAM-Policy"
  })
}

resource "aws_iam_role_policy_attachment" "flow_logs" {
  role       = aws_iam_role.flow_logs_role.name
  policy_arn = aws_iam_policy.flow_logs_policy.arn
}

# VPC Flow Logs
resource "aws_flow_log" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.flow_logs_role.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  # Enhanced flow log format for better security analysis
  log_format = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${windowstart} $${windowend} $${action} $${flowlogstatus} $${vpc-id} $${subnet-id} $${instance-id} $${tcp-flags} $${type} $${pkt-srcaddr} $${pkt-dstaddr} $${region} $${az-id} $${sublocation-type} $${sublocation-id}"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc-flowlogs"
    Type = "VPC-FlowLogs"
  })
}

# Enable GuardDuty
resource "aws_guardduty_detector" "main" {
  count = var.enable_guardduty ? 1 : 0

  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  # Enable S3 protection
  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-guardduty"
    Type = "GuardDuty-Detector"
  })
}

# CloudWatch Dashboard for Zero Trust monitoring
resource "aws_cloudwatch_dashboard" "zero_trust_dashboard" {
  dashboard_name = "${var.project_name}-${var.environment}-zero-trust-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/VPC", "PacketsDropped"],
            ["AWS/VPC", "BytesIn"],
            ["AWS/VPC", "BytesOut"]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "VPC Network Metrics"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          query  = <<EOF
SOURCE '${aws_cloudwatch_log_group.flow_logs.name}'
| fields @timestamp, srcaddr, dstaddr, srcport, dstport, protocol, action
| filter action = "REJECT"
| stats count() by srcaddr, dstaddr
| sort count desc
| limit 20
EOF
          region = data.aws_region.current.name
          title  = "Top Rejected Connections"
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          query  = <<EOF
SOURCE '${aws_cloudwatch_log_group.flow_logs.name}'
| fields @timestamp, srcaddr, dstaddr, srcport, dstport, bytes
| filter srcaddr not like /^10\./
| stats count() as external_connections by srcaddr
| sort external_connections desc
| limit 10
EOF
          region = data.aws_region.current.name
          title  = "External IP Connections"
          view   = "table"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-dashboard"
    Type = "CloudWatch-Dashboard"
  })
}

# CloudWatch Alarms for security monitoring

# Alarm for high rejected connections
resource "aws_cloudwatch_log_metric_filter" "rejected_connections" {
  name           = "${var.project_name}-${var.environment}-rejected-connections"
  log_group_name = aws_cloudwatch_log_group.flow_logs.name
  pattern        = "[version, account, eni, source, destination, srcport, destport, protocol, packets, bytes, windowstart, windowend, action=\"REJECT\", ...]"

  metric_transformation {
    name      = "RejectedConnections"
    namespace = "${var.project_name}/${var.environment}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_rejected_connections" {
  alarm_name          = "${var.project_name}-${var.environment}-high-rejected-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RejectedConnections"
  namespace           = "${var.project_name}/${var.environment}/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "This metric monitors rejected connections"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = merge(var.common_tags, {
    Name     = "${var.project_name}-${var.environment}-rejected-connections-alarm"
    Type     = "CloudWatch-Alarm"
    Severity = "High"
  })
}

# Alarm for unusual traffic patterns
resource "aws_cloudwatch_log_metric_filter" "unusual_traffic" {
  name           = "${var.project_name}-${var.environment}-unusual-traffic"
  log_group_name = aws_cloudwatch_log_group.flow_logs.name
  pattern        = "[version, account, eni, source, destination, srcport, destport=\"22\" || destport=\"3389\" || destport=\"1433\" || destport=\"3306\", ...]"

  metric_transformation {
    name      = "UnusualTraffic"
    namespace = "${var.project_name}/${var.environment}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unusual_traffic_alarm" {
  alarm_name          = "${var.project_name}-${var.environment}-unusual-traffic"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnusualTraffic"
  namespace           = "${var.project_name}/${var.environment}/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors unusual traffic to sensitive ports"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = merge(var.common_tags, {
    Name     = "${var.project_name}-${var.environment}-unusual-traffic-alarm"
    Type     = "CloudWatch-Alarm"
    Severity = "High"
  })
}

# SNS Topic for security alerts
resource "aws_sns_topic" "security_alerts" {
  name              = "${var.project_name}-${var.environment}-security-alerts"
  kms_master_key_id = aws_kms_key.main.id

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-security-alerts"
    Type    = "SNS-Topic"
    Purpose = "Security-Alerts"
  })
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "security_alerts_policy" {
  arn = aws_sns_topic.security_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "cloudwatch.amazonaws.com",
            "guardduty.amazonaws.com"
          ]
        }
        Action = [
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.security_alerts.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Security Hub (if available in region)
resource "aws_securityhub_account" "main" {
  count                    = var.enable_guardduty ? 1 : 0
  enable_default_standards = true

  depends_on = [aws_guardduty_detector.main]
}

# Enable Config for compliance monitoring
resource "aws_config_configuration_recorder_status" "main" {
  count      = var.enable_guardduty ? 1 : 0
  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}

resource "aws_config_configuration_recorder" "main" {
  count    = var.enable_guardduty ? 1 : 0
  name     = "${var.project_name}-${var.environment}-config-recorder"
  role_arn = aws_iam_role.config_role[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }

  depends_on = [aws_config_delivery_channel.main]
}

resource "aws_config_delivery_channel" "main" {
  count          = var.enable_guardduty ? 1 : 0
  name           = "${var.project_name}-${var.environment}-config-delivery-channel"
  s3_bucket_name = aws_s3_bucket.config_bucket[0].bucket
}

# S3 bucket for Config
resource "aws_s3_bucket" "config_bucket" {
  count  = var.enable_guardduty ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-config-${random_id.config_bucket_suffix[0].hex}"

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-config-bucket"
    Type    = "S3-Bucket"
    Purpose = "Config"
  })
}

resource "aws_s3_bucket_versioning" "config_bucket" {
  count  = var.enable_guardduty ? 1 : 0
  bucket = aws_s3_bucket.config_bucket[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "config_bucket" {
  count  = var.enable_guardduty ? 1 : 0
  bucket = aws_s3_bucket.config_bucket[0].id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.main.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "config_bucket" {
  count  = var.enable_guardduty ? 1 : 0
  bucket = aws_s3_bucket.config_bucket[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Random ID for config bucket suffix
resource "random_id" "config_bucket_suffix" {
  count       = var.enable_guardduty ? 1 : 0
  byte_length = 4
}

# IAM Role for Config
resource "aws_iam_role" "config_role" {
  count = var.enable_guardduty ? 1 : 0
  name  = "${var.project_name}-${var.environment}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-config-role"
    Type    = "IAM-Role"
    Service = "Config"
  })
}

resource "aws_iam_role_policy_attachment" "config_role_policy" {
  count      = var.enable_guardduty ? 1 : 0
  role       = aws_iam_role.config_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigServiceRolePolicy"
}

# Custom Config rule for Security Group compliance
resource "aws_config_config_rule" "security_group_ssh_restricted" {
  count = var.enable_guardduty ? 1 : 0
  name  = "${var.project_name}-${var.environment}-sg-ssh-restricted"

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-sg-ssh-restricted"
    Type    = "Config-Rule"
    Purpose = "Security-Compliance"
  })
}

# Config rule for encrypted EBS volumes
resource "aws_config_config_rule" "encrypted_volumes" {
  count = var.enable_guardduty ? 1 : 0
  name  = "${var.project_name}-${var.environment}-encrypted-volumes"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  depends_on = [aws_config_configuration_recorder.main]

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-encrypted-volumes"
    Type    = "Config-Rule"
    Purpose = "Encryption-Compliance"
  })
}

# CloudTrail for API auditing
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-${var.environment}-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket.bucket
  s3_key_prefix                 = "AWSLogs"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  kms_key_id                    = aws_kms_key.main.arn

  event_selector {
    read_write_type                  = "All"
    include_management_events        = true
    exclude_management_event_sources = []

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::${var.project_name}-${var.environment}-*/*"]
    }
  }

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-cloudtrail"
    Type    = "CloudTrail"
    Purpose = "API-Auditing"
  })
}

# S3 bucket for CloudTrail
resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket = "${var.project_name}-${var.environment}-cloudtrail-${random_id.cloudtrail_suffix.hex}"

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-cloudtrail-bucket"
    Type    = "S3-Bucket"
    Purpose = "CloudTrail"
  })
}

resource "aws_s3_bucket_versioning" "cloudtrail_bucket" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "cloudtrail_bucket" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.main.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_bucket" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "random_id" "cloudtrail_suffix" {
  byte_length = 4
}

# CloudTrail bucket policy
resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_bucket.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}