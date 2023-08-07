provider "aws" {
  region                   = "us-east-1"
}

variable "access_key" {
  type = string
}
variable "secret_key" {
  type = string
}

resource "aws_iam_role" "lambda-role" {
  name = "ec2-stop-start-new"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    tag-key = "lambda-ec2-role"
  }
}

resource "aws_iam_policy" "lambda-policy" {
  name = "lambda-ec2-stop-start-new"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:DescribeRegions",
                "ec2:StartInstances",
                "ec2:StopInstances"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_policy_attachment" "lambda-ec2-policy-attachment" {
  name       = "lambda-ec2-policy-attachment"
  roles      = ["${aws_iam_role.lambda-role.name}"]
  policy_arn = aws_iam_policy.lambda-policy.arn
}

resource "aws_lambda_function" "ec2-stop-start" {
  filename      = "lambda.zip"
  function_name = "lambda"
  role          = aws_iam_role.lambda-role.arn
  handler       = "lambda.lambda_handler"

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = filebase64sha256("lambda.zip")

  runtime = "python3.9"

  timeout = 63
}

resource "aws_cloudwatch_event_rule" "ec2-rule" {
  name                = "ec2-rule"
  description         = "Trigger ec2 stop instance every 1 min"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "lambda-func" {
  target_id = "lambda"
  rule      = aws_cloudwatch_event_rule.ec2-rule.name
  arn       = aws_lambda_function.ec2-stop-start.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2-stop-start.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ec2-rule.arn
}