# Secrets + KMS - the "three-gate" credential isolation model.
#
#   Gate 1 (the Map):   the registry DB stores only secret ARNs (Phase 5 / app).
#   Gate 2 (the Vault): Secrets Manager holds the actual connection strings.
#   Gate 3 (the Key):   this customer-managed KMS key, usable only by the app
#                       roles and only via the KMS / Secrets Manager VPC endpoints.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  # Role names + DETERMINISTIC ARNs computed from the (known) account id, so the KMS
  # key policy is fully resolved at plan time and there is no key <-> role cycle.
  execution_role_name = "${var.project}-${var.environment}-ecs-execution-role-${var.aws_region}-01"
  task_role_name      = "${var.project}-${var.environment}-ecs-task-role-${var.aws_region}-01"
  execution_role_arn  = "arn:${local.partition}:iam::${local.account_id}:role/${local.execution_role_name}"
  task_role_arn       = "arn:${local.partition}:iam::${local.account_id}:role/${local.task_role_name}"

  # Per-tenant secret ARN pattern (app creates these at runtime).
  tenant_secret_arn_pattern = "arn:${local.partition}:secretsmanager:${var.aws_region}:${local.account_id}:secret:${var.tenant_secret_prefix}*"

  secretsmanager_via_service = "secretsmanager.${var.aws_region}.amazonaws.com"
}

# ---------------------------------------------------------------------------
# KMS customer-managed key (Gate 3)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "kms_key_policy" {
  # 1) Account admins may ADMINISTER the key but NOT use it for crypto.
  statement {
    sid    = "KeyAdministrationNoCrypto"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = concat(["arn:${local.partition}:iam::${local.account_id}:root"], var.kms_admin_principal_arns)
    }
    actions = [
      "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*",
      "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*",
      "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion",
    ]
    resources = ["*"]
  }

  # 2a) App roles may use the key for crypto when the call is mediated by Secrets
  #     Manager (boot secrets + per-tenant SM secrets), restricted to the VPC endpoints.
  statement {
    sid    = "AllowCryptoViaSecretsManager"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.execution_role_arn, local.task_role_arn]
    }
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey*", "kms:ReEncrypt*"]
    resources = ["*"]
    # NOTE: aws:SourceVpce intentionally NOT applied here. Secrets Manager makes the
    # KMS call on the caller's behalf and does not reliably set aws:SourceVpce, which
    # would lock out boot-secret decryption. kms:ViaService is the safe binding for
    # the SM path; aws:SourceVpce is enforced on the direct-crypto path below.
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = [local.secretsmanager_via_service]
    }
  }

  # 2b) The task role may use the key for DIRECT crypto only when the TenantID
  #     encryption-context key is present (value not pinned), via the VPC endpoints.
  statement {
    sid    = "AllowDirectCryptoWithTenantIdContext"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.task_role_arn]
    }
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey*", "kms:ReEncrypt*"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpce"
      values   = [var.kms_vpc_endpoint_id, var.secretsmanager_vpc_endpoint_id]
    }
    # TenantID context key must be PRESENT...
    condition {
      test     = "Null"
      variable = "kms:EncryptionContext:${var.tenant_kms_encryption_context_key}"
      values   = ["false"]
    }
    # ...and it must be the ONLY context key (salts every direct per-tenant crypto).
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "kms:EncryptionContextKeys"
      values   = [var.tenant_kms_encryption_context_key]
    }
  }

  # 2c) Allow the Secrets Manager SERVICE to use the key for crypto on behalf of any
  #     principal in THIS account. This is the AWS-standard pattern: it lets Secrets
  #     Manager encrypt/decrypt account secrets (e.g. Terraform/admins creating
  #     CMK-encrypted secret containers) WITHOUT granting any human direct crypto on
  #     the key - all use is mediated by Secrets Manager (kms:ViaService).
  statement {
    sid    = "AllowSecretsManagerServiceUse"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
    actions = [
      "kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*",
      "kms:ReEncrypt*", "kms:DescribeKey", "kms:CreateGrant",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = [local.secretsmanager_via_service]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [local.account_id]
    }
  }

  # 2d) Allow AWS services (RDS, ElastiCache, ...) to use the key for storage
  #     encryption on behalf of this account, scoped by kms:ViaService. Created only
  #     when aws_service_via_services is non-empty. No human gets direct crypto.
  dynamic "statement" {
    for_each = length(var.aws_service_via_services) > 0 ? [1] : []
    content {
      sid    = "AllowAwsServiceUseViaService"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
      }
      actions = [
        "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
        "kms:GenerateDataKey*", "kms:DescribeKey", "kms:CreateGrant",
      ]
      resources = ["*"]
      condition {
        test     = "StringEquals"
        variable = "kms:CallerAccount"
        values   = [local.account_id]
      }
      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = var.aws_service_via_services
      }
    }
  }

  # 3) Allow the app roles to DescribeKey via the endpoints (no crypto, no context).
  statement {
    sid    = "AllowDescribeKeyViaEndpoint"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.execution_role_arn, local.task_role_arn]
    }
    actions   = ["kms:DescribeKey"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpce"
      values   = [var.kms_vpc_endpoint_id, var.secretsmanager_vpc_endpoint_id]
    }
  }
}

resource "aws_kms_key" "this" {
  description             = "${var.project}-${var.environment} customer-managed key for Secrets Manager (three-gate model)"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = var.kms_enable_key_rotation
  policy                  = data.aws_iam_policy_document.kms_key_policy.json

  tags = {
    Name        = "${var.project}-${var.environment}-secrets-cmk-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.project}-${var.environment}-secrets"
  target_key_id = aws_kms_key.this.key_id
}

# ---------------------------------------------------------------------------
# IAM roles
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# --- Task EXECUTION role: ECR pull, read boot secrets, write logs ---
resource "aws_iam_role" "execution" {
  name               = local.execution_role_name
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json

  tags = {
    Name        = local.execution_role_name
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# ECR pull + CloudWatch Logs create/put (AWS managed).
resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Read the bundled app secret at task start (for the ECS task-def `secrets` injection).
data "aws_iam_policy_document" "execution_secrets" {
  statement {
    sid       = "ReadAppSecret"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [aws_secretsmanager_secret.app.arn]
  }
  statement {
    sid       = "KmsDecryptAppSecret"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.this.arn]
  }
}

resource "aws_iam_policy" "execution_secrets" {
  name        = "${var.project}-${var.environment}-ecs-execution-secrets-${var.aws_region}-01"
  description = "Allow the ECS execution role to read the boot secrets for task startup injection"
  policy      = data.aws_iam_policy_document.execution_secrets.json

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "execution_secrets" {
  role       = aws_iam_role.execution.name
  policy_arn = aws_iam_policy.execution_secrets.arn
}

# --- Task RUNTIME role: the application's AWS identity ---
resource "aws_iam_role" "task" {
  name               = local.task_role_name
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json

  tags = {
    Name        = local.task_role_name
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

data "aws_iam_policy_document" "task" {
  # Provision + read per-tenant secrets under the tenant path.
  statement {
    sid = "TenantSecretsProvisionAndRead"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:TagResource",
      "secretsmanager:DeleteSecret", # tenant offboarding (adopted from live)
    ]
    resources = [local.tenant_secret_arn_pattern]
  }

  # Read the bundled app secret at runtime (DB creds, JWT keys, encryption key, etc.).
  statement {
    sid       = "ReadAppSecret"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [aws_secretsmanager_secret.app.arn]
  }

  # Use the CMK (key policy enforces the VPC-endpoint + context conditions).
  statement {
    sid = "KmsUseForSecrets"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:ReEncrypt*",
      "kms:DescribeKey",
    ]
    resources = [aws_kms_key.this.arn, aws_kms_key.tenant.arn]
  }

  # NOTE: S3 access to the three buckets is added to this role in Phase 5.
  # NOTE: deliberately NO RDS IAM permissions - tenant DB/role creation happens
  #       in-Postgres (CREATEDB/CREATEROLE), not via IAM.
}

resource "aws_iam_policy" "task" {
  name        = "${var.project}-${var.environment}-ecs-task-${var.aws_region}-01"
  description = "Runtime app identity: per-tenant secret provisioning/read, boot-secret read, CMK use"
  policy      = data.aws_iam_policy_document.task.json

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "task" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task.arn
}

# ---------------------------------------------------------------------------
# Bundled app secret (EMPTY container - value, a JSON bundle, populated out-of-band)
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "app" {
  name                    = var.app_secret_name
  description             = "Bundled application boot secret (JSON) for ${var.project}-${var.environment} (value populated out-of-band)"
  kms_key_id              = aws_kms_key.this.arn
  recovery_window_in_days = var.app_secret_recovery_window_days

  tags = {
    Name        = var.app_secret_name
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# ---------------------------------------------------------------------------
# Dedicated tenant-secrets KMS key (scoped to the prod ECS task role)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "tenant_kms_key" {
  statement {
    sid       = "Enable IAM User Permissions"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }

  # Key administrators (only rendered when admin principals are supplied - an empty
  # principals list is invalid in a policy document).
  dynamic "statement" {
    for_each = length(var.kms_admin_principal_arns) > 0 ? [1] : []
    content {
      sid    = "Allow access for Key Administrators"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.kms_admin_principal_arns
      }
      actions = [
        "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*",
        "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*",
        "kms:TagResource", "kms:UntagResource", "kms:RotateKeyOnDemand",
      ]
      resources = ["*"]
    }
  }

  statement {
    sid       = "Allow use of the key"
    effect    = "Allow"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [local.task_role_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${var.aws_region}.amazonaws.com"]
    }
  }

  statement {
    sid       = "Allow attachment of persistent resources"
    effect    = "Allow"
    actions   = ["kms:CreateGrant", "kms:ListGrants", "kms:RevokeGrant"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [local.task_role_arn]
    }
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  statement {
    sid       = "DenyDataUseExceptTaskRole"
    effect    = "Deny"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey*", "kms:ReEncrypt*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalArn"
      values   = [local.task_role_arn]
    }
  }
}

resource "aws_kms_key" "tenant" {
  description             = "${var.project}-${var.environment} tenant secrets key"
  enable_key_rotation     = false
  deletion_window_in_days = var.kms_deletion_window_days
  policy                  = data.aws_iam_policy_document.tenant_kms_key.json

  tags = {
    Name        = "${var.project}-${var.environment}-tenant-secrets-cmk-${var.aws_region}-01"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_kms_alias" "tenant" {
  name          = "alias/${var.project}-${var.environment}-tenant-secrets"
  target_key_id = aws_kms_key.tenant.key_id
}
