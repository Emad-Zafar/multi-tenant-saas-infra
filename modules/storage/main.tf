# Prod S3 buckets: static-assets, media-assets, knowledge-base.
# All private, SSE (AES256 / SSE-S3), public access fully blocked.
# Plus an S3 access policy attached to the existing ECS task role.

resource "aws_s3_bucket" "this" {
  for_each = var.bucket_names
  bucket   = each.value

  tags = {
    Name        = each.value
    Environment = var.environment
    Project     = var.project
    Purpose     = each.key
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  # Avatar buckets (static_assets) have ALL FOUR blocks disabled to match live - the
  # app uploads avatars with public-read object ACLs, so the ACL blocks must be off too.
  block_public_acls  = contains(var.avatar_public_bucket_keys, each.key) ? false : true
  ignore_public_acls = contains(var.avatar_public_bucket_keys, each.key) ? false : true
  # Buckets with any public policy (full-public media_assets, or avatar-scoped
  # static_assets) must allow a public bucket policy; knowledge_base keeps all four true.
  block_public_policy     = contains(var.public_bucket_keys, each.key) || contains(var.avatar_public_bucket_keys, each.key) ? false : true
  restrict_public_buckets = contains(var.public_bucket_keys, each.key) || contains(var.avatar_public_bucket_keys, each.key) ? false : true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# CORS for browser direct uploads/downloads (adopted from the dev's manual CLI change).
resource "aws_s3_bucket_cors_configuration" "this" {
  for_each = var.cors_rules
  bucket   = aws_s3_bucket.this[each.key].id

  cors_rule {
    allowed_headers = each.value.allowed_headers
    allowed_methods = each.value.allowed_methods
    allowed_origins = each.value.allowed_origins
    expose_headers  = each.value.expose_headers
    max_age_seconds = each.value.max_age_seconds
  }
}

# --- S3 access policy attached to the existing ECS task role ---
data "aws_iam_policy_document" "task_s3" {
  statement {
    sid       = "BucketLevel"
    actions   = ["s3:ListBucket"]
    resources = [for b in aws_s3_bucket.this : b.arn]
  }
  statement {
    sid       = "ObjectLevel"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [for b in aws_s3_bucket.this : "${b.arn}/*"]
  }
}

resource "aws_iam_policy" "task_s3" {
  name        = "${var.project}-${var.environment}-ecs-task-s3-${var.aws_region}-01"
  description = "Allow the ECS task role to access the three prod S3 buckets"
  policy      = data.aws_iam_policy_document.task_s3.json

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "task_s3" {
  role       = var.task_role_name
  policy_arn = aws_iam_policy.task_s3.arn
}

# --- Per-bucket bucket policies (back-filled to match manual CLI state) ---
data "aws_iam_policy_document" "bucket" {
  for_each = aws_s3_bucket.this

  statement {
    sid       = "AllowProdEcsRoleAccess"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [each.value.arn, "${each.value.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = [var.task_role_arn]
    }
  }

  # media_assets is fully publicly readable (bucket/*); knowledge_base is NOT.
  dynamic "statement" {
    for_each = contains(var.public_bucket_keys, each.key) ? [1] : []
    content {
      sid       = "PublicReadStaticAssets"
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = ["${each.value.arn}/*"]
      principals {
        type        = "*"
        identifiers = ["*"]
      }
    }
  }

  # static_assets is otherwise private but serves PUBLIC user avatars, scoped to
  # <bucket>/*/user-avatars/* only (adopted from live to match the dev's CLI change).
  dynamic "statement" {
    for_each = contains(var.avatar_public_bucket_keys, each.key) ? [1] : []
    content {
      sid       = "AllowPublicAvatarAccess"
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = ["${each.value.arn}/*/user-avatars/*"]
      principals {
        type        = "*"
        identifiers = ["*"]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  policy   = data.aws_iam_policy_document.bucket[each.key].json

  # For public buckets the BPA must relax block_public_policy first.
  depends_on = [aws_s3_bucket_public_access_block.this]
}
