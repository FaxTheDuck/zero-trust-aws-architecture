# Step 1: VPC Micro-Segmentation

## Overview

This step implements the foundational networking layer of our Zero Trust architecture by creating a VPC with strict micro-segmentation principles. The network is divided into multiple trust zones with explicit security controls.

## Architecture Components

### Network Segmentation

Our VPC is segmented into three distinct tiers:

#### 1. Public Subnet (DMZ Zone)
- **Purpose**: Load balancers and bastion hosts only
- **CIDR**: `10.0.1.0/24`, `10.0.2.0/24`
- **Internet Access**: Full outbound and inbound via Internet Gateway
- **Security Level**: Medium (controlled by ALB/WAF)

#### 2. Private Application Subnet (Internal Zone)
- **Purpose**: Application servers and containers
- **CIDR**: `10.0.10.0/24`, `10.0.11.0/24`
- **Internet Access**: Outbound only via NAT Gateway
- **Security Level**: High (no direct internet access)

#### 3. Private Database Subnet (Restricted Zone)
- **Purpose**: Databases and sensitive data stores
- **CIDR**: `10.0.20.0/24`, `10.0.21.0/24`
- **Internet Access**: None (isolated)
- **Security Level**: Maximum (completely isolated)

## Security Groups (Application-Level Firewall)

### ALB Security Group
```hcl
# Allows HTTP/HTTPS from internet
ingress {
  from_port   = 80/443
  to_port     = 80/443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# Only allows outbound to app subnets
egress {
  from_port   = 8080
  to_port     = 8080
  protocol    = "tcp"
  cidr_blocks = ["10.0.10.0/24", "10.0.11.0/24"]
}
```

### Application Security Group
```hcl
# Only accepts traffic from ALB
ingress {
  from_port       = 8080
  to_port         = 8080
  protocol        = "tcp"
  security_groups = [aws_security_group.alb.id]
}

# Only connects to database
egress {
  from_port       = 5432
  to_port         = 5432
  protocol        = "tcp"
  security_groups = [aws_security_group.db.id]
}
```

### Database Security Group
```hcl
# Only accepts traffic from application servers
ingress {
  from_port       = 5432
  to_port         = 5432
  protocol        = "tcp"
  security_groups = [aws_security_group.app.id]
}

# No outbound rules (deny all)
```

## Network ACLs (Subnet-Level Firewall)

Network ACLs provide an additional layer of defense with subnet-level controls:

### Public Subnet NACLs
- Allow HTTP/HTTPS inbound from internet
- Allow outbound to application subnets on port 8080
- Allow ephemeral ports for return traffic

### Private Application Subnet NACLs
- Allow inbound from public subnets on port 8080
- Allow outbound to database subnets on port 5432
- Allow HTTPS outbound for AWS API calls

### Private Database Subnet NACLs
- Allow inbound from application subnets on port 5432
- Allow ephemeral ports outbound to application subnets
- Deny all other traffic

## Zero Trust Principles Implementation

### 1. Never Trust, Always Verify
- **Implementation**: All traffic flows are explicitly defined and verified
- **Example**: App servers can only receive traffic from verified ALB sources

### 2. Least Privilege Access
- **Implementation**: Security groups with minimum required permissions
- **Example**: Database servers have no outbound internet access

### 3. Micro-Segmentation
- **Implementation**: Each subnet represents a separate trust zone
- **Example**: Direct communication between public and database subnets is blocked

## Traffic Flow Examples

### Legitimate User Request
```
Internet → ALB (Public) → App Server (Private App) → Database (Private DB)
   ✅         ✅               ✅                     ✅
```

### Blocked Lateral Movement
```
Compromised App Server → Direct Database Access (Different Subnet)
           ✅                         ❌
```

### Blocked Internet Access from Database
```
Database Server → Internet
       ✅           ❌
```

## Configuration Files

### Primary Configuration
- **File**: `terraform/vpc.tf`
- **Purpose**: VPC, subnets, routing, and NAT gateways
- **Key Resources**: VPC, Subnets, Route Tables, NAT Gateways

### Security Configuration
- **File**: `terraform/security.tf`
- **Purpose**: Security Groups and Network ACLs
- **Key Resources**: Security Groups, NACLs, NACL Rules

## Deployment Commands

```bash
# Plan the network infrastructure
terraform plan -target=aws_vpc.main
terraform plan -target=aws_subnet.public
terraform plan -target=aws_subnet.private_app
terraform plan -target=aws_subnet.private_db

# Apply network configuration
terraform apply -target=module.vpc
```

## Verification Steps

After deployment, verify the micro-segmentation:

```bash
# Check VPC and subnets
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*zero-trust*"
aws ec2 describe-subnets --filters "Name=tag:Type,Values=Public-Subnet"

# Verify security groups
aws ec2 describe-security-groups --filters "Name=tag:Type,Values=ALB-SecurityGroup"

# Check route tables
aws ec2 describe-route-tables --filters "Name=tag:Type,Values=Private-DB-Route-Table"
```

## Security Benefits

### Network Isolation
- **Benefit**: Prevents lateral movement between zones
- **Implementation**: Route table restrictions and security group boundaries

### Defense in Depth
- **Benefit**: Multiple layers of security (SG + NACL)
- **Implementation**: Both application and network-level controls

### Controlled Internet Access
- **Benefit**: Minimizes attack surface
- **Implementation**: Database subnets have no internet routes

## Common Issues and Solutions

### Issue: Cannot connect to database from application
**Solution**: Verify security group allows traffic on database port (5432)

### Issue: Application cannot reach internet for updates
**Solution**: Ensure NAT Gateway is properly configured and route table is associated

### Issue: High NAT Gateway costs
**Solution**: Consider VPC endpoints for AWS services to reduce internet traffic

## Next Steps

After completing VPC micro-segmentation:

1. **[Step 2](./step2-privatelink.md)**: Configure AWS PrivateLink to eliminate public exposure
2. **Verify Network Flows**: Test connectivity between tiers
3. **Monitor Traffic**: Review VPC Flow Logs for unexpected connections
4. **Security Testing**: Perform penetration testing to validate segmentation

## Cost Considerations

- **NAT Gateways**: ~$45/month per gateway (2 gateways = ~$90/month)
- **Data Processing**: $0.045 per GB processed through NAT Gateway
- **VPC**: No additional cost for VPC itself
- **Route Tables/Subnets**: No additional cost

## Compliance Benefits

This micro-segmentation approach helps with:
- **PCI DSS**: Network segmentation requirements
- **SOC 2**: Security boundary controls
- **ISO 27001**: Network access control
- **NIST Framework**: Network segmentation and isolation

---

**Security Note**: This implementation provides a strong foundation for Zero Trust networking. Regular security assessments and monitoring are essential to maintain effectiveness.