terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source para account ID
data "aws_caller_identity" "current" {}

# S3 Bucket - Raw Data
resource "aws_s3_bucket" "raw_data" {
  bucket = "glue-raw-data-${data.aws_caller_identity.current.account_id}"
  
  tags = {
    Name        = "Glue Raw Data"
    Environment = var.environment
    Project     = "DataPipeline"
  }
}

resource "aws_s3_bucket_versioning" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket - Processed Data
resource "aws_s3_bucket" "processed_data" {
  bucket = "glue-processed-data-${data.aws_caller_identity.current.account_id}"
  
  tags = {
    Name        = "Glue Processed Data"
    Environment = var.environment
    Project     = "DataPipeline"
  }
}

resource "aws_s3_bucket_versioning" "processed_data" {
  bucket = aws_s3_bucket.processed_data.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket - Glue Scripts
resource "aws_s3_bucket" "glue_scripts" {
  bucket = "glue-scripts-${data.aws_caller_identity.current.account_id}"
  
  tags = {
    Name        = "Glue Scripts"
    Environment = var.environment
    Project     = "DataPipeline"
  }
}

# S3 Bucket - Athena Results
resource "aws_s3_bucket" "athena_results" {
  bucket = "athena-results-${data.aws_caller_identity.current.account_id}"
  
  tags = {
    Name        = "Athena Query Results"
    Environment = var.environment
    Project     = "DataPipeline"
  }
}

# Upload Glue script
resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.glue_scripts.id
  key    = "scripts/consolidate_data.py"
  source = "${path.module}/../glue_jobs/consolidate_data.py"
  etag   = filemd5("${path.module}/../glue_jobs/consolidate_data.py")
}

# Upload Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/api_fetcher.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_s3_object" "lambda_code" {
  bucket = aws_s3_bucket.glue_scripts.id
  key    = "lambda/api_fetcher.zip"
  source = data.archive_file.lambda_zip.output_path
  etag   = filemd5(data.archive_file.lambda_zip.output_path)
}

# IAM Role para Glue
resource "aws_iam_role" "glue_role" {
  name = "GlueDataPipelineRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3_policy" {
  name = "GlueS3Access"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.raw_data.arn}/*",
          "${aws_s3_bucket.processed_data.arn}/*",
          "${aws_s3_bucket.glue_scripts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.raw_data.arn,
          aws_s3_bucket.processed_data.arn,
          aws_s3_bucket.glue_scripts.arn
        ]
      }
    ]
  })
}

# IAM Role para Lambda
resource "aws_iam_role" "lambda_role" {
  name = "LambdaAPIFetcherRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "LambdaS3Access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.raw_data.arn}/*"
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "api_fetcher" {
  function_name = "cep-api-fetcher"
  role         = aws_iam_role.lambda_role.arn
  handler      = "api_fetcher.lambda_handler"
  runtime      = "python3.11"
  timeout      = 60
  
  s3_bucket = aws_s3_bucket.glue_scripts.id
  s3_key    = aws_s3_object.lambda_code.key
  
  environment {
    variables = {
      RAW_BUCKET = aws_s3_bucket.raw_data.id
      API_URL    = var.cep_api_url
    }
  }
}

# EventBridge Rule para executar Lambda
resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  name                = "cep-api-fetcher-schedule"
  description         = "Trigger Lambda to fetch CEP data"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.lambda_schedule.name
  target_id = "lambda"
  arn       = aws_lambda_function.api_fetcher.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_fetcher.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_schedule.arn
}

# Glue Database
resource "aws_glue_catalog_database" "data_pipeline" {
  name = "data_pipeline_db"
  
  description = "Database for consolidated data pipeline"
}

# Glue Crawler para Raw Data
resource "aws_glue_crawler" "raw_data_crawler" {
  name          = "raw-data-crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.data_pipeline.name

  s3_target {
    path = "s3://${aws_s3_bucket.raw_data.id}/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }
}

# Athena Workgroup
resource "aws_athena_workgroup" "data_pipeline" {
  name = "data-pipeline-workgroup"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.id}/results/"
    }
  }
}
