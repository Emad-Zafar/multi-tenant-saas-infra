# lambda-edge-og module outputs

output "lambda_edge_og_qualified_arn" {
  description = "Versioned (qualified) function ARN - what CloudFront Lambda@Edge requires"
  value       = aws_lambda_function.this.qualified_arn
}

output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.this.function_name
}
