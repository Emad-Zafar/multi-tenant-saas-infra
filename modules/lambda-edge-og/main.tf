# Lambda@Edge link-preview (OG tag) function. Created in us-east-1 via the caller's
# aws.us_east_1 provider. No env vars (Lambda@Edge forbids them), no external deps.

data "archive_file" "this" {
  type        = "zip"
  source_file = "${path.module}/src/index.js"
  output_path = "${path.module}/build/lambda-edge-og.zip"
}

# Trust policy must allow BOTH lambda and edgelambda to assume the role.
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = {
    Name        = "${var.function_name}-role"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role             = aws_iam_role.this.arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256
  timeout          = var.timeout
  memory_size      = var.memory
  publish          = true # required for Lambda@Edge - gives a versioned ARN

  tags = {
    Name        = var.function_name
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}
