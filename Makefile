# SaaS Infrastructure Makefile
# Usage: make <target>

# Default environment
ENV ?= staging

.PHONY: help init plan apply destroy clean validate fmt output state-list

# Default target
help:
	@echo "SaaS Infrastructure Management"
	@echo ""
	@echo "Available targets:"
	@echo "  init        - Initialize Terraform for staging environment"
	@echo "  plan        - Plan changes for staging environment"
	@echo "  apply       - Apply changes to staging environment"
	@echo "  destroy     - Destroy staging environment"
	@echo "  output      - Show outputs for staging environment"
	@echo "  state-list  - List resources in state"
	@echo "  validate    - Validate Terraform configurations"
	@echo "  fmt         - Format Terraform code"
	@echo "  clean       - Clean up local Terraform files"
	@echo ""
	@echo "Examples:"
	@echo "  make init"
	@echo "  make plan"
	@echo "  make apply"

# Initialize Terraform
init:
	@echo "Initializing staging environment..."
	@cd environments/staging && terraform init

# Plan changes
plan:
	@echo "Planning staging environment..."
	@cd environments/staging && terraform plan -var-file=stg.tfvars

# Apply changes
apply:
	@echo "Applying staging environment..."
	@cd environments/staging && terraform apply -var-file=stg.tfvars

# Destroy infrastructure
destroy:
	@echo "Destroying staging environment..."
	@cd environments/staging && terraform destroy -var-file=stg.tfvars

# Show outputs
output:
	@echo "Outputs for staging environment:"
	@cd environments/staging && terraform output

# List state
state-list:
	@echo "Current state for staging environment:"
	@cd environments/staging && terraform state list

# Validate Terraform configurations
validate:
	@echo "Validating Terraform configurations..."
	@cd environments/staging && terraform validate

# Format Terraform code
fmt:
	@echo "Formatting Terraform code..."
	@terraform fmt -recursive

# Clean up local Terraform files
clean:
	@echo "Cleaning up local Terraform files..."
	@find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@find . -name "terraform.tfstate" -delete 2>/dev/null || true
	@find . -name "terraform.tfstate.backup" -delete 2>/dev/null || true
