# VPC and Networking Configuration for Zero Trust Architecture

# Main VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc"
    Type = "Main-VPC"
  })
}

# Internet Gateway for public subnets
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-igw"
    Type = "Internet-Gateway"
  })
}

# Public Subnets (ALB, Bastion Host only)
resource "aws_subnet" "public" {
  count = var.availability_zones_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-subnet-${count.index + 1}"
    Type = "Public-Subnet"
    Tier = "Web"
    Zone = "DMZ"
  })
}

# Private Application Subnets
resource "aws_subnet" "private_app" {
  count = var.availability_zones_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-app-subnet-${count.index + 1}"
    Type = "Private-App-Subnet"
    Tier = "Application"
    Zone = "Internal"
  })
}

# Private Database Subnets
resource "aws_subnet" "private_db" {
  count = var.availability_zones_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_db_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-subnet-${count.index + 1}"
    Type = "Private-DB-Subnet"
    Tier = "Database"
    Zone = "Restricted"
  })
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = var.availability_zones_count

  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-eip-nat-${count.index + 1}"
    Type = "NAT-EIP"
  })

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways for private subnets
resource "aws_nat_gateway" "main" {
  count = var.availability_zones_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat-${count.index + 1}"
    Type = "NAT-Gateway"
  })

  depends_on = [aws_internet_gateway.main]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-rt"
    Type = "Public-Route-Table"
  })
}

resource "aws_route_table" "private_app" {
  count = var.availability_zones_count

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-app-rt-${count.index + 1}"
    Type = "Private-App-Route-Table"
  })
}

resource "aws_route_table" "private_db" {
  count = var.availability_zones_count

  vpc_id = aws_vpc.main.id

  # No default route to internet for DB subnets (Zero Trust principle)

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-rt-${count.index + 1}"
    Type = "Private-DB-Route-Table"
  })
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count = var.availability_zones_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_app" {
  count = var.availability_zones_count

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

resource "aws_route_table_association" "private_db" {
  count = var.availability_zones_count

  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db[count.index].id
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.private_db[*].id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
    Type = "DB-Subnet-Group"
  })
}