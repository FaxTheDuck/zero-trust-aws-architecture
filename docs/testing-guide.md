# Zero Trust Application Testing Guide

This guide provides comprehensive instructions for testing your Zero Trust architecture implementation using the included web application.

## 🚀 Quick Test (Local Development)

### 1. Prerequisites Check
```bash
# Check if all required tools are installed
./scripts/deploy-application.sh check
```

### 2. Test Backend Locally
```bash
cd application/backend

# Copy environment file
cp .env.example .env

# Install dependencies
npm install

# Start the application
npm start
```

The backend will run on `http://localhost:8080`

### 3. Test Endpoints
```bash
# Health check (should return 200)
curl http://localhost:8080/health

# Zero Trust status (should return infrastructure info)
curl http://localhost:8080/api/zero-trust-status

# Protected endpoint (should return 401)
curl http://localhost:8080/api/protected/dashboard
```

## 🏗️ Full Infrastructure Test

### 1. Deploy Infrastructure
```bash
# Deploy the Zero Trust infrastructure first
./scripts/deploy.sh

# Wait for completion, then deploy application
./scripts/deploy-application.sh deploy
```

### 2. Application Testing
The deployment script will automatically:
- ✅ Build and push Docker image to ECR
- ✅ Deploy to ECS Fargate
- ✅ Create test user in Cognito
- ✅ Run integration tests
- ✅ Validate Zero Trust components

## 🧪 Manual Testing Procedures

### Authentication Testing

1. **Test Unauthenticated Access**
   ```bash
   # Should return 401 Unauthorized
   curl -i http://YOUR-ALB-DNS/api/protected/dashboard
   ```

2. **Test with Invalid Token**
   ```bash
   # Should return 401 Unauthorized
   curl -H "Authorization: Bearer invalid-token" \
        http://YOUR-ALB-DNS/api/protected/dashboard
   ```

3. **Test with Valid Token** (requires Cognito authentication)
   - Use the web interface to login
   - Extract JWT token from browser developer tools
   - Test API calls with valid token

### Network Security Testing

1. **VPC Flow Logs Analysis**
   ```bash
   # Check if flow logs are capturing traffic
   aws logs describe-log-groups --log-group-name-prefix "/aws/vpc/flowlogs"
   
   # View recent flow log entries
   aws logs filter-log-events \
       --log-group-name "/aws/vpc/flowlogs/zero-trust-arch-dev" \
       --start-time $(date -d '1 hour ago' +%s)000
   ```

2. **Security Group Validation**
   ```bash
   # Check security group rules
   aws ec2 describe-security-groups \
       --filters "Name=vpc-id,Values=YOUR-VPC-ID" \
       --query 'SecurityGroups[*].{GroupId:GroupId,Rules:IpPermissions}'
   ```

3. **VPC Endpoint Testing**
   ```bash
   # Verify VPC endpoints are working
   aws ec2 describe-vpc-endpoints \
       --filters "Name=vpc-id,Values=YOUR-VPC-ID" \
       --query 'VpcEndpoints[*].{Service:ServiceName,State:State}'
   ```

### Monitoring and Alerting Testing

1. **GuardDuty Findings**
   ```bash
   # Check for security findings
   aws guardduty list-findings \
       --detector-id YOUR-DETECTOR-ID \
       --region us-west-2
   ```

2. **CloudWatch Metrics**
   ```bash
   # Check application metrics
   aws cloudwatch get-metric-statistics \
       --namespace AWS/ApplicationELB \
       --metric-name RequestCount \
       --start-time $(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%S) \
       --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
       --period 300 \
       --statistics Sum
   ```

## 🔐 Security Validation Tests

### 1. Zero Trust Principles Validation

**Never Trust, Always Verify**
- ✅ All API endpoints require authentication
- ✅ JWT tokens are validated with Cognito
- ✅ No implicit trust between network segments

**Least Privilege Access**
- ✅ Security groups follow minimum required access
- ✅ Database subnets have no internet access
- ✅ IAM roles have scoped permissions

**Micro-segmentation**
- ✅ Separate subnets for different tiers
- ✅ NACLs provide subnet-level controls
- ✅ No direct cross-tier communication

### 2. Application Security Tests

```bash
# Test injection attacks (should be blocked)
curl -X POST http://YOUR-ALB-DNS/api/protected/dashboard \
     -H "Content-Type: application/json" \
     -d '{"query": "SELECT * FROM users WHERE id = 1; DROP TABLE users;"}'

# Test XSS attempts (should be sanitized)
curl -X POST http://YOUR-ALB-DNS/api/protected/dashboard \
     -H "Content-Type: application/json" \
     -d '{"input": "<script>alert(\"xss\")</script>"}'

# Test CSRF protection
curl -X POST http://YOUR-ALB-DNS/api/protected/dashboard \
     -H "Origin: https://malicious-site.com"
```

### 3. Network Penetration Testing

```bash
# Test port scanning detection (should trigger GuardDuty)
nmap -sS YOUR-ALB-IP

# Test brute force detection
for i in {1..100}; do
    curl -X POST http://YOUR-ALB-DNS/login \
         -d "username=admin&password=password$i"
done
```

## 📊 Performance Testing

### Load Testing with curl
```bash
# Simple load test
for i in {1..100}; do
    curl -w "%{time_total}\n" -o /dev/null -s http://YOUR-ALB-DNS/health &
done
wait
```

### Load Testing with Apache Bench
```bash
# Install Apache Bench
sudo apt-get install apache2-utils

# Run load test
ab -n 1000 -c 10 http://YOUR-ALB-DNS/health
```

## 🐛 Troubleshooting

### Common Issues

1. **Application Not Responding**
   ```bash
   # Check ECS service status
   aws ecs describe-services \
       --cluster YOUR-CLUSTER-NAME \
       --services YOUR-SERVICE-NAME
   
   # Check application logs
   aws logs tail /ecs/zero-trust-arch-dev --follow
   ```

2. **Authentication Failures**
   ```bash
   # Verify Cognito configuration
   aws cognito-idp describe-user-pool \
       --user-pool-id YOUR-USER-POOL-ID
   ```

3. **Network Connectivity Issues**
   ```bash
   # Check VPC configuration
   aws ec2 describe-vpcs --vpc-ids YOUR-VPC-ID
   
   # Check route tables
   aws ec2 describe-route-tables \
       --filters "Name=vpc-id,Values=YOUR-VPC-ID"
   ```

### Debug Mode

Enable debug logging:
```bash
export LOG_LEVEL=debug
export ENABLE_DEBUG_LOGGING=true
```

## 📝 Test Report Generation

The deployment script automatically generates a test report:
```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "environment": {
    "project": "zero-trust-arch",
    "environment": "dev",
    "region": "us-west-2"
  },
  "test_results": {
    "health_check": "200",
    "zero_trust_status": "200",
    "authentication_protection": "401"
  },
  "zero_trust_validation": {
    "vpc_flow_logs": "1",
    "security_groups": "8",
    "vpc_endpoints": "10"
  }
}
```

## 🎯 Success Criteria

Your Zero Trust implementation is successful if:

- ✅ **Health check returns 200**
- ✅ **Unauthenticated requests return 401**
- ✅ **VPC Flow Logs are active**
- ✅ **GuardDuty is monitoring**
- ✅ **VPC endpoints are available**
- ✅ **Security groups follow least privilege**
- ✅ **No internet access from database subnets**
- ✅ **All traffic encrypted in transit**

## 🔄 Continuous Testing

Set up automated testing:

1. **CloudWatch Alarms** for application health
2. **GuardDuty findings** for security alerts
3. **VPC Flow Logs analysis** for network anomalies
4. **Regular penetration testing** for vulnerability assessment

## 🧹 Cleanup

To destroy the test environment:
```bash
# Destroy application infrastructure
terraform destroy -target=aws_ecs_service.app
terraform destroy -target=aws_ecs_cluster.main
terraform destroy -target=aws_lb.app

# Destroy core infrastructure
./scripts/deploy.sh destroy
```

---

**Security Note**: Always test in a non-production environment first. Some tests may trigger security alerts or temporarily impact service availability.