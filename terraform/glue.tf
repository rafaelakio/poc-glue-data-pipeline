# Glue Job para consolidar dados
resource "aws_glue_job" "consolidate_data" {
  name     = "data-consolidation-job"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.glue_scripts.id}/scripts/consolidate_data.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = "s3://${aws_s3_bucket.glue_scripts.id}/spark-logs/"
    "--TempDir"                          = "s3://${aws_s3_bucket.glue_scripts.id}/temp/"
    "--RAW_BUCKET"                       = aws_s3_bucket.raw_data.id
    "--PROCESSED_BUCKET"                 = aws_s3_bucket.processed_data.id
    "--DATABASE_NAME"                    = aws_glue_catalog_database.data_pipeline.name
  }

  max_retries       = 1
  timeout           = 60
  glue_version      = "4.0"
  number_of_workers = 2
  worker_type       = "G.1X"

  execution_property {
    max_concurrent_runs = 1
  }
}

# Glue Crawler para Processed Data
resource "aws_glue_crawler" "processed_data_crawler" {
  name          = "processed-data-crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.data_pipeline.name

  s3_target {
    path = "s3://${aws_s3_bucket.processed_data.id}/consolidated/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
  })
}

# Glue Trigger para executar o job após o Lambda
resource "aws_glue_trigger" "start_consolidation" {
  name     = "start-consolidation-trigger"
  type     = "SCHEDULED"
  schedule = "cron(0 */2 * * ? *)" # A cada 2 horas

  actions {
    job_name = aws_glue_job.consolidate_data.name
  }
}

# Glue Trigger para executar crawler após o job
resource "aws_glue_trigger" "crawl_processed_data" {
  name = "crawl-processed-data-trigger"
  type = "CONDITIONAL"

  actions {
    crawler_name = aws_glue_crawler.processed_data_crawler.name
  }

  predicate {
    conditions {
      job_name = aws_glue_job.consolidate_data.name
      state    = "SUCCEEDED"
    }
  }
}
