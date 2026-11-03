#!/bin/bash

# Bootstrap script to create Terraform backend resources
# This script creates the S3 bucket and DynamoDB table for Terraform state management

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
S3_BUCKET="saas-tf-state"
DYNAMODB_TABLE="saas-tf-state-lock"
AWS_PROFILE="terraform-ci"
AWS_REGION="eu-north-1"

echo -e "${GREEN}SaaS Terraform Backend Bootstrap${NC}"
echo "=========================================="
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

# Check if AWS profile exists
if ! aws configure list-profiles | grep -q "^${AWS_PROFILE}$"; then
    echo -e "${YELLOW}Warning: AWS profile '${AWS_PROFILE}' not found${NC}"
    echo "Please configure it using: aws configure --profile ${AWS_PROFILE}"
    exit 1
fi

echo -e "${GREEN}✓ AWS profile '${AWS_PROFILE}' found${NC}"

# Create S3 bucket for state storage
echo ""
echo -e "${YELLOW}Creating S3 bucket: ${S3_BUCKET}${NC}"

if aws s3 ls "s3://${S3_BUCKET}" --profile "${AWS_PROFILE}" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3 mb "s3://${S3_BUCKET}" \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}"
    echo -e "${GREEN}✓ S3 bucket created${NC}"
else
    echo -e "${YELLOW}✓ S3 bucket already exists${NC}"
fi

# Enable versioning
echo -e "${YELLOW}Enabling S3 bucket versioning...${NC}"
aws s3api put-bucket-versioning \
    --bucket "${S3_BUCKET}" \
    --versioning-configuration Status=Enabled \
    --profile "${AWS_PROFILE}" \
    --region "${AWS_REGION}"
echo -e "${GREEN}✓ Versioning enabled${NC}"

# Enable encryption
echo -e "${YELLOW}Enabling S3 bucket encryption...${NC}"
aws s3api put-bucket-encryption \
    --bucket "${S3_BUCKET}" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }' \
    --profile "${AWS_PROFILE}" \
    --region "${AWS_REGION}"
echo -e "${GREEN}✓ Encryption enabled${NC}"

# Block public access
echo -e "${YELLOW}Blocking public access...${NC}"
aws s3api put-public-access-block \
    --bucket "${S3_BUCKET}" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --profile "${AWS_PROFILE}" \
    --region "${AWS_REGION}"
echo -e "${GREEN}✓ Public access blocked${NC}"

# Create DynamoDB table for state locking
echo ""
echo -e "${YELLOW}Creating DynamoDB table: ${DYNAMODB_TABLE}${NC}"

if aws dynamodb describe-table \
    --table-name "${DYNAMODB_TABLE}" \
    --profile "${AWS_PROFILE}" \
    --region "${AWS_REGION}" 2>&1 | grep -q 'ResourceNotFoundException'; then
    
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}"
    
    echo -e "${YELLOW}Waiting for table to be active...${NC}"
    aws dynamodb wait table-exists \
        --table-name "${DYNAMODB_TABLE}" \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}"
    
    echo -e "${GREEN}✓ DynamoDB table created${NC}"
else
    echo -e "${YELLOW}✓ DynamoDB table already exists${NC}"
fi

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}Backend setup completed successfully!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Navigate to environments/staging"
echo "2. Run: terraform init"
echo "3. Run: terraform plan -var-file=staging.tfvars"
echo "4. Run: terraform apply -var-file=staging.tfvars"
echo ""

