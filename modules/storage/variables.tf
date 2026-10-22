# Input variables for the Storage module (3 prod S3 buckets + task-role S3 policy).

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

variable "bucket_names" {
  description = "Map of logical key -> S3 bucket name for the three prod buckets. Names must be globally unique."
  type        = map(string)
  default = {
    static_assets  = "saas-prod-static-assets"
    media_assets   = "saas-prod-media-assets"
    knowledge_base = "saas-prod-knowledge-base"
  }
}

variable "task_role_name" {
  description = "Name of the ECS task role to attach the S3 access policy to (from the secrets module)"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the ECS task role (principal in the per-bucket bucket policies)"
  type        = string
}

variable "public_bucket_keys" {
  description = "Bucket keys that get a FULL-bucket public s3:GetObject statement (bucket/*) + relaxed BPA. static_assets is NOT here - it gets only the narrow avatar statement (see avatar_public_bucket_keys)."
  type        = list(string)
  default     = ["media_assets"]
}

variable "avatar_public_bucket_keys" {
  description = "Bucket keys that get a NARROW public s3:GetObject on <bucket>/*/user-avatars/* only (public avatars), plus relaxed BPA. Adopted from live: static_assets serves public user avatars but is otherwise private."
  type        = list(string)
  default     = ["static_assets"]
}

variable "cors_rules" {
  description = "Per-bucket CORS config (logical key -> rule). Buckets absent from the map get no CORS configuration. Adopted from live browser-upload settings."
  type = map(object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = list(string)
    max_age_seconds = number
  }))
  default = {}
}
