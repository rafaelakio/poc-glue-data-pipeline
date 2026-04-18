# Comandos Úteis - Pipeline AWS Glue

## Terraform

### Inicialização e Deploy
```bash
# Inicializar
cd terraform
terraform init

# Validar
terraform validate

# Planejar
terraform plan

# Aplicar
terraform apply -auto-approve

# Ver outputs
terraform output

# Destruir tudo
terraform destroy -auto-approve
```

### Gerenciamento de Estado
```bash
# Ver estado atual
terraform show

# Listar recursos
terraform state list

# Ver recurso específico
terraform state show aws_s3_bucket.raw_data

# Refresh estado
terraform refresh
```

## AWS CLI - S3

### Gerenciamento de Buckets
```bash
# Listar buckets
aws s3 ls

# Listar conteúdo de bucket
aws s3 ls s3://bucket-name/ --recursive

# Upload arquivo
aws s3 cp local-file.csv s3://bucket-name/path/

# Upload pasta
aws s3 cp local-folder/ s3://bucket-name/path/ --recursive

# Download arquivo
aws s3 cp s3://bucket-name/path/file.csv ./

# Sync pasta
aws s3 sync local-folder/ s3://bucket-name/path/

# Deletar arquivo
aws s3 rm s3://bucket-name/path/file.csv

# Deletar pasta
aws s3 rm s3://bucket-name/path/ --recursive

# Esvaziar bucket
aws s3 rm s3://bucket-name/ --recursive
```

## AWS CLI - Lambda

### Gerenciamento de Funções
```bash
# Listar funções
aws lambda list-functions

# Ver detalhes da função
aws lambda get-function --function-name cep-api-fetcher

# Invocar função
aws lambda invoke \
  --function-name cep-api-fetcher \
  --payload '{}' \
  response.json

# Ver logs
aws logs tail /aws/lambda/cep-api-fetcher --follow

# Ver logs das últimas 2 horas
aws logs tail /aws/lambda/cep-api-fetcher --since 2h

# Atualizar código da função
aws lambda update-function-code \
  --function-name cep-api-fetcher \
  --zip-file fileb://function.zip
```

## AWS CLI - Glue

### Jobs
```bash
# Listar jobs
aws glue list-jobs

# Ver detalhes do job
aws glue get-job --job-name data-consolidation-job

# Executar job
aws glue start-job-run --job-name data-consolidation-job

# Executar job com argumentos
aws glue start-job-run \
  --job-name data-consolidation-job \
  --arguments '{"--additional-arg":"value"}'

# Listar execuções do job
aws glue get-job-runs --job-name data-consolidation-job

# Ver execução específica
aws glue get-job-run \
  --job-name data-consolidation-job \
  --run-id jr_xxxxx

# Parar execução
aws glue batch-stop-job-run \
  --job-name data-consolidation-job \
  --job-run-ids jr_xxxxx

# Ver logs do job
aws logs tail /aws-glue/jobs/output --follow
aws logs tail /aws-glue/jobs/error --follow
```

### Crawlers
```bash
# Listar crawlers
aws glue list-crawlers

# Ver detalhes do crawler
aws glue get-crawler --name processed-data-crawler

# Executar crawler
aws glue start-crawler --name processed-data-crawler

# Parar crawler
aws glue stop-crawler --name processed-data-crawler

# Ver métricas do crawler
aws glue get-crawler-metrics --crawler-name-list processed-data-crawler
```

### Database e Tables
```bash
# Listar databases
aws glue get-databases

# Ver database
aws glue get-database --name data_pipeline_db

# Listar tabelas
aws glue get-tables --database-name data_pipeline_db

# Ver tabela específica
aws glue get-table \
  --database-name data_pipeline_db \
  --name consolidated_vendas

# Ver partições
aws glue get-partitions \
  --database-name data_pipeline_db \
  --table-name consolidated_vendas

# Deletar tabela
aws glue delete-table \
  --database-name data_pipeline_db \
  --name table_name
```

## AWS CLI - Athena

### Queries
```bash
# Listar workgroups
aws athena list-work-groups

# Executar query
QUERY_ID=$(aws athena start-query-execution \
  --query-string "SELECT * FROM consolidated_vendas LIMIT 10" \
  --query-execution-context Database=data_pipeline_db \
  --result-configuration OutputLocation=s3://athena-results-bucket/results/ \
  --query 'QueryExecutionId' --output text)

# Ver status da query
aws athena get-query-execution --query-execution-id $QUERY_ID

# Ver resultados
aws athena get-query-results --query-execution-id $QUERY_ID

# Listar queries executadas
aws athena list-query-executions

# Parar query
aws athena stop-query-execution --query-execution-id $QUERY_ID
```

## AWS CLI - CloudWatch Logs

### Visualização de Logs
```bash
# Listar log groups
aws logs describe-log-groups

# Ver logs em tempo real
aws logs tail /aws/lambda/cep-api-fetcher --follow

# Ver logs das últimas N horas
aws logs tail /aws-glue/jobs/output --since 2h

# Filtrar logs
aws logs filter-log-events \
  --log-group-name /aws/lambda/cep-api-fetcher \
  --filter-pattern "ERROR"

# Ver streams de log
aws logs describe-log-streams \
  --log-group-name /aws/lambda/cep-api-fetcher
```

## AWS CLI - IAM

### Roles e Políticas
```bash
# Listar roles
aws iam list-roles

# Ver role
aws iam get-role --role-name GlueDataPipelineRole

# Listar políticas anexadas
aws iam list-attached-role-policies --role-name GlueDataPipelineRole

# Ver política
aws iam get-policy --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole

# Ver versão da política
aws iam get-policy-version \
  --policy-arn arn:aws:iam::account-id:policy/policy-name \
  --version-id v1
```

## Scripts de Automação

### Deploy Completo
```bash
#!/bin/bash
# deploy.sh

set -e

echo "=== Iniciando deploy ==="

# 1. Deploy infraestrutura
cd terraform
terraform init
terraform apply -auto-approve

# 2. Obter outputs
RAW_BUCKET=$(terraform output -raw raw_data_bucket)
LAMBDA_FUNCTION=$(terraform output -raw lambda_function_name)
GLUE_JOB=$(terraform output -raw glue_job_name)

# 3. Upload dados
cd ..
aws s3 cp sample_data/vendas.csv s3://$RAW_BUCKET/vendas/
aws s3 cp sample_data/clientes.json s3://$RAW_BUCKET/clientes/

# 4. Executar pipeline
aws lambda invoke --function-name $LAMBDA_FUNCTION response.json
sleep 10
aws glue start-job-run --job-name $GLUE_JOB

echo "=== Deploy concluído ==="
```

### Monitoramento
```bash
#!/bin/bash
# monitor.sh

GLUE_JOB="data-consolidation-job"

# Ver última execução
LAST_RUN=$(aws glue get-job-runs \
  --job-name $GLUE_JOB \
  --max-results 1 \
  --query 'JobRuns[0].[Id,JobRunState,ExecutionTime]' \
  --output text)

echo "Última execução: $LAST_RUN"

# Ver logs
aws logs tail /aws-glue/jobs/output --since 1h
```

### Limpeza
```bash
#!/bin/bash
# cleanup.sh

set -e

echo "=== Iniciando limpeza ==="

# 1. Esvaziar buckets
cd terraform
RAW_BUCKET=$(terraform output -raw raw_data_bucket)
PROCESSED_BUCKET=$(terraform output -raw processed_data_bucket)
SCRIPTS_BUCKET=$(terraform output -raw glue_scripts_bucket)
ATHENA_BUCKET=$(terraform output -raw athena_results_bucket)

aws s3 rm s3://$RAW_BUCKET --recursive
aws s3 rm s3://$PROCESSED_BUCKET --recursive
aws s3 rm s3://$SCRIPTS_BUCKET --recursive
aws s3 rm s3://$ATHENA_BUCKET --recursive

# 2. Destruir infraestrutura
terraform destroy -auto-approve

echo "=== Limpeza concluída ==="
```

## Variáveis de Ambiente Úteis

```bash
# Exportar outputs do Terraform
export RAW_BUCKET=$(cd terraform && terraform output -raw raw_data_bucket)
export PROCESSED_BUCKET=$(cd terraform && terraform output -raw processed_data_bucket)
export GLUE_JOB=$(cd terraform && terraform output -raw glue_job_name)
export LAMBDA_FUNCTION=$(cd terraform && terraform output -raw lambda_function_name)
export ATHENA_BUCKET=$(cd terraform && terraform output -raw athena_results_bucket)
export DATABASE_NAME=$(cd terraform && terraform output -raw glue_database_name)

# Usar variáveis
aws s3 ls s3://$RAW_BUCKET/
aws glue start-job-run --job-name $GLUE_JOB
```

## Atalhos e Aliases

```bash
# Adicionar ao ~/.bashrc ou ~/.zshrc

# Terraform
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'
alias tfo='terraform output'

# AWS
alias s3ls='aws s3 ls'
alias s3cp='aws s3 cp'
alias s3rm='aws s3 rm'

# Glue
alias glue-jobs='aws glue list-jobs'
alias glue-run='aws glue start-job-run --job-name'
alias glue-status='aws glue get-job-runs --job-name'

# Lambda
alias lambda-invoke='aws lambda invoke --function-name'
alias lambda-logs='aws logs tail /aws/lambda'

# Athena
alias athena-query='aws athena start-query-execution'
```
