# Security Groups and Network ACLs for Zero Trust Micro-Segmentation

# Security Group for Application Load Balancer (Public Subnet)
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for Application Load Balancer"

  # Allow HTTP/HTTPS from internet (controlled by WAF if implemented)
  ingress {
    description = "HTTP from Internet"
    from_port   = var.web_port
    to_port     = var.web_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    description = "HTTPS from Internet"
    from_port   = var.https_port
    to_port     = var.https_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Allow all outbound traffic to private app subnets only
  egress {
    description = "To App Subnets"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = var.private_app_subnet_cidrs
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-alb-sg"
    Type = "ALB-SecurityGroup"
    Tier = "Web"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for Bastion Host (if needed)
resource "aws_security_group" "bastion" {
  name_prefix = "${var.project_name}-${var.environment}-bastion-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for Bastion Host"

  # SSH access from specific IPs only (Zero Trust principle)
  ingress {
    description = "SSH from Trusted IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_TRUSTED_IP/32"] # Replace with actual trusted IPs
  }

  # Allow SSH to private app subnets only
  egress {
    description = "SSH to App Subnets"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.private_app_subnet_cidrs
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-bastion-sg"
    Type = "Bastion-SecurityGroup"
    Tier = "Management"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for Application Servers (Private App Subnet)
resource "aws_security_group" "app" {
  name_prefix = "${var.project_name}-${var.environment}-app-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for Application Servers"

  # Allow traffic from ALB only
  ingress {
    description     = "HTTP from ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow SSH from bastion host only
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # Database access will be defined as separate rule to avoid circular dependency

  # Allow HTTPS outbound for API calls to AWS services (via VPC endpoints)
  egress {
    description = "HTTPS for AWS Services"
    from_port   = var.https_port
    to_port     = var.https_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow DNS resolution
  egress {
    description = "DNS Resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-app-sg"
    Type = "App-SecurityGroup"
    Tier = "Application"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for Database (Private DB Subnet)
resource "aws_security_group" "db" {
  name_prefix = "${var.project_name}-${var.environment}-db-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for Database"

  # Database access from app will be defined as separate rule to avoid circular dependency

  # No outbound rules - database should not initiate outbound connections

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-sg"
    Type = "DB-SecurityGroup"
    Tier = "Database"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.project_name}-${var.environment}-vpce-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for VPC Endpoints"

  # Allow HTTPS from private subnets
  ingress {
    description = "HTTPS from Private Subnets"
    from_port   = var.https_port
    to_port     = var.https_port
    protocol    = "tcp"
    cidr_blocks = concat(var.private_app_subnet_cidrs, var.private_db_subnet_cidrs)
  }

  # Allow all outbound (for AWS service communication)
  egress {
    description = "All Outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpce-sg"
    Type = "VPCEndpoint-SecurityGroup"
    Tier = "Infrastructure"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Network ACLs for additional layer of security

# Public Subnet NACL
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  # Allow HTTP inbound
  ingress {
    rule_no     = 100
    protocol    = "tcp"
    rule_action = "allow"
    from_port   = var.web_port
    to_port     = var.web_port
    cidr_block  = "0.0.0.0/0"
  }

  # Allow HTTPS inbound
  ingress {
    rule_no     = 110
    protocol    = "tcp"
    rule_action = "allow"
    from_port   = var.https_port
    to_port     = var.https_port
    cidr_block  = "0.0.0.0/0"
  }

  # Allow ephemeral ports for responses
  ingress {
    rule_no     = 120
    protocol    = "tcp"
    rule_action = "allow"
    from_port   = 1024
    to_port     = 65535
    cidr_block  = "0.0.0.0/0"
  }

  # Allow outbound to app subnets
  egress {
    rule_no     = 100
    protocol    = "tcp"
    rule_action = "allow"
    from_port   = var.app_port
    to_port     = var.app_port
    cidr_block  = var.private_app_subnet_cidrs[0]
  }

  egress {
    rule_no     = 110
    protocol    = "tcp"
    rule_action = "allow"
    from_port   = var.app_port
    to_port     = var.app_port
    cidr_block  = var.private_app_subnet_cidrs[1]
  }

  # Allow ephemeral ports outbound
  egress {
    rule_no     = 120
    protocol    = "tcp"
    rule_action = "allow"
    from_port   = 1024
    to_port     = 65535
    cidr_block  = "0.0.0.0/0"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-nacl"
    Type = "Public-NACL"
    Tier = "Web"
  })
}

# Private App Subnet NACL
resource "aws_network_acl" "private_app" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private_app[*].id

  # Allow inbound from ALB (public subnets)
  ingress {
    rule_no     = 100
    protocol    = "tcp"
    rule_action = "allow"
    from_port   = var.app_port
    to_port     = var.app_port
    cidr_block  = var.public_subnet_cidrs[0]
  }

  ingress {
    rule_no     = 110
    protocol    = "tcp"
    rule_action = "allow"
    from_port   = var.app_port
    to_port     = var.app_port
    cidr_block  = var.public_subnet_cidrs[1]
  }

  # Allow SSH from bastion (public subnet)
  ingress {
    rule_no     = 120
    protocol    = "tcp"
    rule_action = "allow"
    from_port   = 22
    to_port     = 22
    cidr_block  = var.public_subnet_cidrs[0]
  }

  # Allow ephemeral ports
  ingress {
    rule_no     = 130
    protocol    = "tcp"
    rule_action = "allow"
    from_port   = 1024
    to_port     = 65535
    cidr_block  = "0.0.0.0/0"
  }

  # Allow outbound to database subnets
  egress {
    rule_no     = 100
    protocol    = "tcp"
    rule_action = "allow"
    from_port   = var.db_port
    to_port     = var.db_port
    cidr_block  = var.private_db_subnet_cidrs[0]
  }

  egress {
    rule_no     = 110
    protocol    = "tcp"
    rule_action = "allow"
    from_port   = var.db_port
    to_port     = var.db_port
    cidr_block  = var.private_db_subnet_cidrs[1]
  }

  # Allow HTTPS outbound (for AWS services)
  egress {
    rule_no     = 120
    protocol    = "tcp"
    rule_action = "allow"
    from_port   = var.https_port
    to_port     = var.https_port
    cidr_block  = "0.0.0.0/0"
  }

  # Allow ephemeral ports outbound
  egress {
    rule_no     = 130
    protocol    = "tcp"
    rule_action = "allow"
    from_port   = 1024
    to_port     = 65535
    cidr_block  = "0.0.0.0/0"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-app-nacl"
    Type = "App-NACL"
    Tier = "Application"
  })
}

# Private DB Subnet NACL
resource "aws_network_acl" "private_db" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private_db[*].id

  # Allow database traffic from app subnets only
  ingress {
    rule_no     = 100
    protocol    = "tcp"
    rule_action = "allow"
    from_port   = var.db_port
    to_port     = var.db_port
    cidr_block  = var.private_app_subnet_cidrs[0]
  }

  ingress {
    rule_no     = 110
    protocol    = "tcp"
    rule_action = "allow"
    from_port   = var.db_port
    to_port     = var.db_port
    cidr_block  = var.private_app_subnet_cidrs[1]
  }

  # Allow ephemeral ports for responses
  egress {
    rule_no     = 100
    protocol    = "tcp"
    rule_action = "allow"
    from_port   = 1024
    to_port     = 65535
    cidr_block  = var.private_app_subnet_cidrs[0]
  }

  egress {
    rule_no     = 110
    protocol    = "tcp"
    rule_action = "allow"
    from_port   = 1024
    to_port     = 65535
    cidr_block  = var.private_app_subnet_cidrs[1]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-nacl"
    Type = "DB-NACL"
    Tier = "Database"
  })
}

# Security Group Rules to avoid circular dependencies

# App to DB rule
resource "aws_security_group_rule" "app_to_db" {
  type                     = "egress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.db.id
  description              = "Allow app to access database"
}

# DB from App rule  
resource "aws_security_group_rule" "db_from_app" {
  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = aws_security_group.app.id
  description              = "Allow database access from app servers"
}
