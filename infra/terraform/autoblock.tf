# Auto-block Lambda — subscribes to WAF logs and adds blocked source IPs
# to the same blocklist IP set referenced by the WAF ACL.

data "archive_file" "autoblock" {
  type        = "zip"
  source_file = "${path.module}/../lambda/waf_autoblock/index.py"
  output_path = "${path.module}/.terraform/waf_autoblock.zip"
}

resource "aws_iam_role" "autoblock" {
  name = "${var.project_name}-autoblock-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "autoblock_basic" {
  role       = aws_iam_role.autoblock.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "autoblock_waf" {
  name = "${var.project_name}-autoblock-waf"
  role = aws_iam_role.autoblock.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "wafv2:GetIPSet",
        "wafv2:UpdateIPSet",
      ]
      Resource = aws_wafv2_ip_set.blocklist.arn
    }]
  })
}

resource "aws_lambda_function" "autoblock" {
  function_name    = "${var.project_name}-waf-autoblock"
  role             = aws_iam_role.autoblock.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.autoblock.output_path
  source_code_hash = data.archive_file.autoblock.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      IPSET_NAME = aws_wafv2_ip_set.blocklist.name
      IPSET_ID   = aws_wafv2_ip_set.blocklist.id
      WAF_SCOPE  = "REGIONAL"
      # Never block these (your office IP, etc.) — comma-separated CIDRs
      ALLOWLIST = ""
    }
  }
}

resource "aws_cloudwatch_log_group" "autoblock" {
  name              = "/aws/lambda/${var.project_name}-waf-autoblock"
  retention_in_days = 7
}

# Allow the WAF log group to invoke the Lambda
resource "aws_lambda_permission" "autoblock_logs" {
  statement_id  = "AllowExecutionFromCWLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.autoblock.function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.waf.arn}:*"
}

# Subscribe Lambda to the WAF log stream
resource "aws_cloudwatch_log_subscription_filter" "waf_to_autoblock" {
  name            = "${var.project_name}-waf-autoblock"
  log_group_name  = aws_cloudwatch_log_group.waf.name
  filter_pattern  = "{ $.action = \"BLOCK\" }"
  destination_arn = aws_lambda_function.autoblock.arn
  depends_on      = [aws_lambda_permission.autoblock_logs]
}
