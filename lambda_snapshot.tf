resource "aws_iam_role" "snapshot_role" {
  name = "snapshot-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "snapshot_policy" {
  name = "rds-snapshot"
  role = aws_iam_role.snapshot_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["rds:CreateDBSnapshot","rds:DescribeDBInstances"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "rds_snapshot" {
  filename      = "rds_snapshot_lambda.zip"
  function_name = "rds-snapshot"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.10"
  role          = aws_iam_role.snapshot_role.arn
}

resource "aws_cloudwatch_event_rule" "snapshot_rule" {
  name                = "rds-snapshot-every-30-days"
  schedule_expression = "rate(30 days)"
}

resource "aws_cloudwatch_event_target" "snapshot_target" {
  rule      = aws_cloudwatch_event_rule.snapshot_rule.name
  target_id = "snapshot"
  arn       = aws_lambda_function.rds_snapshot.arn
}

resource "aws_lambda_permission" "snapshot_invoke" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rds_snapshot.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.snapshot_rule.arn
}
