output "raw_data_bucket" {
  description = "S3 bucket for raw data"
  value       = aws_s3_bucket.raw_data.id
}

output "processed_data_bucket" {
  description = "S3 bucket for processed data"
  value       = aws_s3_bucket.processed_data.id
}

output "athena_results_bucket" {
  description = "S3 bucket for Athena results"
  value       = aws_s3_bucket.athena_results.id
}

output "glue_database_name" {
  description = "Glue catalog database name"
  value       = aws_glue_catalog_database.data_pipeline.name
}

output "athena_workgroup" {
  description = "Athena workgroup name"
  value       = aws_athena_workgroup.data_pipeline.name
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.api_fetcher.function_name
}

output "glue_job_name" {
  description = "Glue job name"
  value       = aws_glue_job.consolidate_data.name
}
