#!/bin/bash

# Zero Trust Architecture Deployment Script
# This script deploys the Zero Trust architecture using Terraform

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_NAME="zero-trust-aws-architecture"
TERRAFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/terraform"

echo -e "${BLUE}🛡  Zero Trust Network Architecture Deployment${NC}"
echo -e "${BLUE}===============================================${NC}"
echo

# Function to print status messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    # Check if AWS credentials are configured
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "All prerequisites are met."
}

# Function to validate Terraform configuration
validate_terraform() {
    print_status "Validating Terraform configuration..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    if terraform init; then
        print_success "Terraform initialized successfully."
    else
        print_error "Failed to initialize Terraform."
        exit 1
    fi
    
    # Validate configuration
    if terraform validate; then
        print_success "Terraform configuration is valid."
    else
        print_error "Terraform configuration validation failed."
        exit 1
    fi
    
    # Format check
    if terraform fmt -check; then
        print_success "Terraform code is properly formatted."
    else
        print_warning "Terraform code needs formatting. Running 'terraform fmt'..."
        terraform fmt
    fi
}

# Function to plan deployment
plan_deployment() {
    print_status "Creating deployment plan..."
    
    cd "$TERRAFORM_DIR"
    
    # Check if terraform.tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        print_warning "terraform.tfvars not found. Copying from example..."
        cp terraform.tfvars.example terraform.tfvars
        print_warning "Please edit terraform.tfvars with your specific values before continuing."
        read -p "Press Enter to continue after editing terraform.tfvars..."
    fi
    
    # Create plan
    if terraform plan -out=tfplan; then
        print_success "Deployment plan created successfully."
    else
        print_error "Failed to create deployment plan."
        exit 1
    fi
}

# Function to apply deployment
apply_deployment() {
    print_status "Deploying Zero Trust architecture..."
    
    cd "$TERRAFORM_DIR"
    
    # Apply the plan
    if terraform apply tfplan; then
        print_success "Zero Trust architecture deployed successfully!"
    else
        print_error "Deployment failed."
        exit 1
    fi
    
    # Clean up plan file
    rm -f tfplan
}

# Function to display outputs
show_outputs() {
    print_status "Displaying deployment outputs..."
    
    cd "$TERRAFORM_DIR"
    
    echo
    echo -e "${GREEN}🎉 Deployment Summary:${NC}"
    echo -e "${GREEN}=====================${NC}"
    
    # Show key outputs
    echo -e "${BLUE}VPC ID:${NC} $(terraform output -raw vpc_id)"
    echo -e "${BLUE}VPC CIDR:${NC} $(terraform output -raw vpc_cidr)"
    echo -e "${BLUE}AWS Region:${NC} $(terraform output -raw aws_region)"
    echo -e "${BLUE}Project Name:${NC} $(terraform output -raw project_name)"
    echo -e "${BLUE}Environment:${NC} $(terraform output -raw environment)"
    
    echo
    echo -e "${BLUE}CloudWatch Dashboard:${NC}"
    terraform output -raw cloudwatch_dashboard_url
    
    echo
    echo -e "${BLUE}Cognito User Pool:${NC}"
    echo "  ARN: $(terraform output -raw cognito_user_pool_arn)"
    echo "  Endpoint: $(terraform output -raw cognito_user_pool_endpoint)"
    
    echo
    print_success "Zero Trust Network Architecture is now deployed and operational!"
}

# Function to show next steps
show_next_steps() {
    echo
    echo -e "${YELLOW}📋 Next Steps:${NC}"
    echo -e "${YELLOW}===============${NC}"
    echo "1. 📧 Subscribe to the security alerts SNS topic for notifications"
    echo "2. 👥 Create users in the Cognito User Pool"
    echo "3. 🚀 Deploy your applications to the private subnets"
    echo "4. 🔍 Monitor the CloudWatch dashboard for security metrics"
    echo "5. 🔒 Review and adjust security group rules as needed"
    echo "6. 📊 Check VPC Flow Logs for network traffic analysis"
    echo "7. 🛡️ Review GuardDuty findings for threat detection"
    echo
    echo -e "${BLUE}📚 Documentation:${NC} See docs/ directory for detailed guides"
    echo -e "${BLUE}🔧 Configuration:${NC} Modify terraform.tfvars to customize settings"
    echo
}

# Function to show cost information
show_cost_info() {
    echo -e "${YELLOW}💰 Cost Information:${NC}"
    echo -e "${YELLOW}==================${NC}"
    echo "Estimated monthly costs for this architecture:"
    echo "• VPC endpoints: ~\$72/month (10 interface endpoints)"
    echo "• GuardDuty: ~\$4.50/month base + usage"
    echo "• NAT Gateways: ~\$90/month (2 gateways)"
    echo "• Flow Logs storage: Variable based on traffic"
    echo "• CloudTrail: ~\$2/month + S3 storage costs"
    echo "• KMS: ~\$1/month per key"
    echo
    echo "Total estimated cost: ~\$170-200/month (excluding application resources)"
    echo
}

# Main deployment function
main() {
    echo -e "${BLUE}Starting Zero Trust Architecture deployment...${NC}"
    echo
    
    # Get current AWS account info
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(aws configure get region)
    
    echo -e "${BLUE}Target AWS Account:${NC} $ACCOUNT_ID"
    echo -e "${BLUE}Target AWS Region:${NC} $AWS_REGION"
    echo
    
    # Confirmation prompt
    read -p "Do you want to proceed with the deployment? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled."
        exit 0
    fi
    
    # Run deployment steps
    check_prerequisites
    validate_terraform
    plan_deployment
    
    # Final confirmation before apply
    echo
    print_warning "This will create AWS resources that may incur costs."
    read -p "Are you sure you want to apply the changes? (y/N): " final_confirm
    if [[ ! $final_confirm =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled."
        exit 0
    fi
    
    apply_deployment
    show_outputs
    show_cost_info
    show_next_steps
    
    print_success "Zero Trust Architecture deployment completed successfully! 🎉"
}

# Handle script arguments
case "${1:-}" in
    "plan")
        print_status "Running plan only..."
        check_prerequisites
        validate_terraform
        plan_deployment
        ;;
    "apply")
        print_status "Applying existing plan..."
        apply_deployment
        show_outputs
        ;;
    "destroy")
        print_warning "This will destroy all Zero Trust architecture resources!"
        read -p "Are you absolutely sure? Type 'destroy' to confirm: " confirm
        if [[ $confirm == "destroy" ]]; then
            cd "$TERRAFORM_DIR"
            terraform destroy
            print_success "Zero Trust architecture destroyed."
        else
            print_status "Destroy cancelled."
        fi
        ;;
    "outputs")
        cd "$TERRAFORM_DIR"
        show_outputs
        ;;
    *)
        main
        ;;
esac