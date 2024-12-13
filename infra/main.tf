resource "aws_s3_bucket_notification" "target_bucket_notification" {
  bucket = aws_s3_bucket.target.id

  eventbridge {
    events = ["s3:ObjectRemoved:*"]
  }
}

resource "aws_cloudwatch_event_rule" "deleted_files_rule" {
  name        = "deleted-specific-files-rule"
  description = "Trigger for specific deleted files in the target bucket"
  event_pattern = jsonencode({
    source = ["aws.s3"]
    detail = {
      bucket = {
        name = ["target-bucket-name"]
      },
      object = {
        key = [
          "path/to/specific-file-1.txt",
          "path/to/specific-file-2.json"
        ]
      }
    }
  })
}

# Define the AWS provider
provider "aws" {
  region = "us-east-1" # Change to your desired region
}

# Define the S3 bucket for storing the Lambda package
resource "aws_s3_bucket" "lambda_bucket" {
  bucket_prefix = "lambda-code-bucket"
  acl           = "private"
}

# Local file paths
locals {
  lambda_dir  = "./lambda_code"          # Directory containing Lambda code
  zip_file    = "${path.module}/lambda.zip" # Output zip file
}

# Archive the Lambda code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = local.lambda_dir
  output_path = local.zip_file
}

# Upload the Lambda package to S3
resource "aws_s3_object" "lambda_zip" {
  bucket       = aws_s3_bucket.lambda_bucket.id
  key          = "lambda/lambda.zip"
  source       = data.archive_file.lambda_zip.output_path
  content_type = "application/zip"
}

# Create the Lambda function
resource "aws_lambda_function" "example_lambda" {
  function_name = "example-lambda"
  s3_bucket     = aws_s3_bucket.lambda_bucket.id
  s3_key        = aws_s3_object.lambda_zip.key
  handler       = "lambda_function.lambda_handler" # Update with your handler
  runtime       = "python3.9"                      # Update with your runtime

  role          = aws_iam_role.lambda_exec_role.arn
}

# Create an IAM Role for Lambda execution
resource "aws_iam_role" "lambda_exec_role" {
  name               = "lambda-exec-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_policy.json
}

# IAM Role Policy for Lambda execution
data "aws_iam_policy_document" "lambda_assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy_attachment" "lambda_policy_attachment" {
  name       = "lambda-policy-attachment"
  roles      = [aws_iam_role.lambda_exec_role.name]
  policy_arn = aws_iam_policy.AWSLambdaBasicExecutionRole.arn
}

# Attach AWSLambdaBasicExecutionRole Policy
data "aws_iam_policy" "AWSLambdaBasicExecutionRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_event_target" "deleted_files_lambda" {
  rule      = aws_cloudwatch_event_rule.deleted_files_rule.name
  target_id = "deleted-files-lambda"
  arn       = aws_lambda_function.replicate_deleted_files.arn
}
