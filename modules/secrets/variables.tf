# Input variables for the Secrets module (KMS CMK + ECS IAM roles + boot-secret containers).

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-north-1"
}

# --- VPC endpoint IDs for the KMS key policy's aws:SourceVpce binding (Phase 2) ---

variable "kms_vpc_endpoint_id" {
  description = "ID of the KMS interface VPC endpoint (Phase 2). Used in the key policy aws:SourceVpce condition."
  type        = string
}

variable "secretsmanager_vpc_endpoint_id" {
  description = "ID of the Secrets Manager interface VPC endpoint (Phase 2). Used in the key policy aws:SourceVpce condition."
  type        = string
}

# --- Secret naming ---

variable "app_secret_name" {
  description = "Name of the single bundled application secret (JSON bundle of all boot secrets)."
  type        = string
  default     = "saas/prod/app"
}

variable "tenant_secret_prefix" {
  description = "Name prefix under which the app creates per-tenant DB credential secrets at runtime."
  type        = string
  default     = "saas/prod/tenant/"
}

# --- KMS ---

variable "kms_admin_principal_arns" {
  description = "Additional IAM principal ARNs (beyond the account root) allowed to ADMINISTER the CMK. They cannot Encrypt/Decrypt."
  type        = list(string)
  default     = []
}

variable "kms_deletion_window_days" {
  description = "Waiting period (days) before the CMK is deleted after deletion is scheduled."
  type        = number
  default     = 30
}

variable "kms_enable_key_rotation" {
  description = "Enable automatic annual rotation of the CMK."
  type        = bool
  default     = true
}

variable "tenant_kms_encryption_context_key" {
  description = "Encryption-context key that must be present for DIRECT (non-Secrets-Manager) KMS use, so per-tenant envelope crypto is salted by tenant."
  type        = string
  default     = "TenantID"
}

variable "aws_service_via_services" {
  description = "kms:ViaService values for AWS services allowed to use the CMK on behalf of this account (e.g. rds.<region>.amazonaws.com, elasticache.<region>.amazonaws.com). Lets RDS/ElastiCache encrypt storage with the CMK without granting any human direct crypto. Empty = no service usage."
  type        = list(string)
  default     = []
}

variable "app_secret_recovery_window_days" {
  description = "Recovery window (days) for the bundled app secret when deleted. Set 0 to force-delete (not recommended in prod)."
  type        = number
  default     = 30
}
