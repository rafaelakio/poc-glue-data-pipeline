# Guia Rápido - Pipeline de Dados AWS Glue

## Passo a Passo para Deploy

### 1. Pré-requisitos

```bash
# Verificar AWS CLI
aws --version

# Verificar Terraform
terraform --version

# Configurar credenciais AWS
aws configure
```

### 2. Configuração Inicial

```bash
# Clonar/navegar para o projeto
cd poc-glue-data-pipeline

# Copiar arquivo de variáveis
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Editar com seus valores (opcional)
# nano terraform/terraform.tfvars
```

### 3. Deploy da Infraestrutura

```bash
# Inicializar Terraform
cd terraform
terraform init

# Validar configuração
terraform validate

# Ver plano de execução
terraform plan

# Aplicar infraestrutura
terraform apply
# Digite 'yes' quando solicitado

# Anotar os outputs (buckets, nomes, etc)
terraform output
```

### 4. Upload dos Dados de Exemplo

```bash
# Voltar para raiz do projeto
cd ..

# Obter nome do bucket (do output do terraform)
export RAW_BUCKET=$(cd terraform && terraform output -raw raw_data_bucket)

# Upload dos arquivos de exemplo
aws s3 cp sample_data/vendas.csv s3://$RAW_BUCKET/vendas/
aws s3 cp sample_data/clientes.json s3://$RAW_BUCKET/clientes/

# Verificar upload
aws s3 ls s3://$RAW_BUCKET/ --recursive
```

### 5. Executar o Pipeline

```bash
# Invocar Lambda para buscar dados da API
aws lambda invoke \
  --function-name cep-api-fetcher \
  --payload '{}' \
  response.json

# Ver resposta
cat response.json

# Executar Glue Job manualmente
aws glue start-job-run --job-name data-consolidation-job

# Verificar status do job
aws glue get-job-runs --job-name data-consolidation-job --max-results 1
```

### 6. Executar Crawler

```bash
# Executar crawler para catalogar dados processados
aws glue start-crawler --name processed-data-crawler

# Verificar status
aws glue get-crawler --name processed-data-crawler
```

### 7. Consultar no Athena

```bash
# Via Console AWS
# 1. Acesse Athena no console AWS
# 2. Selecione o workgroup: data-pipeline-workgroup
# 3. Selecione o database: data_pipeline_db
# 4. Execute as queries do arquivo queries/sample_queries.sql

# Via CLI
aws athena start-query-execution \
  --query-string "SELECT * FROM consolidated_vendas LIMIT 10" \
  --query-execution-context Database=data_pipeline_db \
  --result-configuration OutputLocation=s3://$(cd terraform && terraform output -raw athena_results_bucket)/results/
```

## Comandos Úteis

### Monitoramento

```bash
# Ver logs do Lambda
aws logs tail /aws/lambda/cep-api-fetcher --follow

# Ver logs do Glue Job
aws logs tail /aws-glue/jobs/output --follow

# Listar execuções do Glue Job
aws glue get-job-runs --job-name data-consolidation-job
```

### Verificação de Dados

```bash
# Listar dados raw
aws s3 ls s3://$RAW_BUCKET/ --recursive

# Listar dados processados
export PROCESSED_BUCKET=$(cd terraform && terraform output -raw processed_data_bucket)
aws s3 ls s3://$PROCESSED_BUCKET/ --recursive

# Ver tabelas no Glue Catalog
aws glue get-tables --database-name data_pipeline_db
```

### Limpeza

```bash
# Remover dados dos buckets (necessário antes do destroy)
aws s3 rm s3://$RAW_BUCKET --recursive
aws s3 rm s3://$PROCESSED_BUCKET --recursive
aws s3 rm s3://$(cd terraform && terraform output -raw glue_scripts_bucket) --recursive
aws s3 rm s3://$(cd terraform && terraform output -raw athena_results_bucket) --recursive

# Destruir infraestrutura
cd terraform
terraform destroy
# Digite 'yes' quando solicitado
```

## Troubleshooting

### Lambda não consegue acessar S3
```bash
# Verificar role do Lambda
aws iam get-role --role-name LambdaAPIFetcherRole

# Verificar políticas anexadas
aws iam list-attached-role-policies --role-name LambdaAPIFetcherRole
```

### Glue Job falha
```bash
# Ver logs detalhados
aws logs tail /aws-glue/jobs/error --follow

# Verificar permissões do role
aws iam get-role --role-name GlueDataPipelineRole
```

### Athena não encontra tabelas
```bash
# Executar crawler novamente
aws glue start-crawler --name processed-data-crawler

# Verificar database
aws glue get-database --name data_pipeline_db

# Listar tabelas
aws glue get-tables --database-name data_pipeline_db
```

## Próximos Passos

1. Personalizar o script Glue para suas necessidades
2. Adicionar mais fontes de dados
3. Configurar alertas no CloudWatch
4. Implementar testes automatizados
5. Adicionar particionamento otimizado
6. Configurar backup e retenção de dados
