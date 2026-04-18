# Guia de Deploy - Pipeline AWS Glue

## Pré-requisitos Detalhados

### 1. Ferramentas Necessárias

```bash
# AWS CLI v2
aws --version
# aws-cli/2.x.x Python/3.x.x

# Terraform
terraform --version
# Terraform v1.0+

# Python (para desenvolvimento local)
python --version
# Python 3.9+
```

### 2. Configuração AWS

```bash
# Configurar credenciais
aws configure
# AWS Access Key ID: [sua-key]
# AWS Secret Access Key: [seu-secret]
# Default region name: us-east-1
# Default output format: json

# Verificar configuração
aws sts get-caller-identity
```

### 3. Permissões IAM Necessárias

O usuário AWS precisa das seguintes permissões:
- S3: CreateBucket, PutObject, GetObject
- Glue: CreateJob, CreateCrawler, CreateDatabase
- Lambda: CreateFunction, InvokeFunction
- IAM: CreateRole, AttachRolePolicy
- EventBridge: PutRule, PutTargets
- Athena: CreateWorkGroup

## Deploy Passo a Passo

### Etapa 1: Preparação

```bash
# Clone ou navegue para o projeto
cd poc-glue-data-pipeline

# Criar arquivo de variáveis
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Editar variáveis (opcional)
# Você pode manter os valores padrão ou customizar
nano terraform/terraform.tfvars
```

### Etapa 2: Validação

```bash
cd terraform

# Inicializar Terraform
terraform init

# Validar sintaxe
terraform validate

# Formatar código
terraform fmt

# Ver plano de execução
terraform plan
```

### Etapa 3: Deploy da Infraestrutura

```bash
# Aplicar infraestrutura
terraform apply

# Revisar o plano e confirmar
# Digite: yes

# Aguardar conclusão (2-5 minutos)
```

### Etapa 4: Verificar Recursos Criados

```bash
# Ver outputs
terraform output

# Salvar outputs em variáveis
export RAW_BUCKET=$(terraform output -raw raw_data_bucket)
export PROCESSED_BUCKET=$(terraform output -raw processed_data_bucket)
export GLUE_JOB=$(terraform output -raw glue_job_name)
export LAMBDA_FUNCTION=$(terraform output -raw lambda_function_name)

# Verificar buckets S3
aws s3 ls | grep glue

# Verificar Glue Job
aws glue get-job --job-name $GLUE_JOB

# Verificar Lambda
aws lambda get-function --function-name $LAMBDA_FUNCTION
```

### Etapa 5: Upload dos Dados de Exemplo

```bash
# Voltar para raiz do projeto
cd ..

# Upload vendas.csv
aws s3 cp sample_data/vendas.csv s3://$RAW_BUCKET/vendas/vendas.csv

# Upload clientes.json
aws s3 cp sample_data/clientes.json s3://$RAW_BUCKET/clientes/clientes.json

# Verificar uploads
aws s3 ls s3://$RAW_BUCKET/ --recursive
```

### Etapa 6: Executar Pipeline Manualmente

```bash
# 1. Executar Lambda para buscar dados da API
aws lambda invoke \
  --function-name $LAMBDA_FUNCTION \
  --payload '{}' \
  response.json

# Ver resposta
cat response.json

# 2. Verificar arquivo criado no S3
aws s3 ls s3://$RAW_BUCKET/api_data/

# 3. Executar Glue Job
JOB_RUN_ID=$(aws glue start-job-run --job-name $GLUE_JOB --query 'JobRunId' --output text)
echo "Job Run ID: $JOB_RUN_ID"

# 4. Monitorar execução do job
aws glue get-job-run --job-name $GLUE_JOB --run-id $JOB_RUN_ID

# Aguardar conclusão (pode levar 3-5 minutos)
# Status: RUNNING -> SUCCEEDED

# 5. Verificar dados processados
aws s3 ls s3://$PROCESSED_BUCKET/consolidated/ --recursive
```

### Etapa 7: Catalogar Dados

```bash
# Executar crawler
aws glue start-crawler --name processed-data-crawler

# Verificar status
aws glue get-crawler --name processed-data-crawler

# Aguardar conclusão (1-2 minutos)
# State: RUNNING -> READY

# Listar tabelas criadas
aws glue get-tables --database-name data_pipeline_db
```

### Etapa 8: Consultar no Athena

#### Via Console AWS

1. Acesse: https://console.aws.amazon.com/athena/
2. Selecione workgroup: `data-pipeline-workgroup`
3. Selecione database: `data_pipeline_db`
4. Execute query:

```sql
SELECT * FROM consolidated_vendas LIMIT 10;
```

#### Via AWS CLI

```bash
# Obter bucket de resultados
ATHENA_BUCKET=$(cd terraform && terraform output -raw athena_results_bucket)

# Executar query
QUERY_ID=$(aws athena start-query-execution \
  --query-string "SELECT * FROM consolidated_vendas LIMIT 10" \
  --query-execution-context Database=data_pipeline_db \
  --result-configuration OutputLocation=s3://$ATHENA_BUCKET/results/ \
  --query 'QueryExecutionId' --output text)

echo "Query ID: $QUERY_ID"

# Verificar status
aws athena get-query-execution --query-execution-id $QUERY_ID

# Ver resultados
aws athena get-query-results --query-execution-id $QUERY_ID
```

## Verificação de Sucesso

### Checklist

- [ ] Buckets S3 criados (4 buckets)
- [ ] Lambda function criada e executando
- [ ] Glue Job criado e executando com sucesso
- [ ] Dados raw no S3 Raw Bucket
- [ ] Dados processados no S3 Processed Bucket (formato Parquet)
- [ ] Glue Crawler executado
- [ ] Tabelas criadas no Glue Catalog
- [ ] Queries funcionando no Athena

### Comandos de Verificação

```bash
# Contar recursos criados
echo "=== S3 Buckets ==="
aws s3 ls | grep -E "glue|athena" | wc -l
# Esperado: 4

echo "=== Lambda Functions ==="
aws lambda list-functions --query 'Functions[?contains(FunctionName, `cep-api`)].FunctionName'
# Esperado: ["cep-api-fetcher"]

echo "=== Glue Jobs ==="
aws glue list-jobs --query 'JobNames[?contains(@, `consolidation`)]'
# Esperado: ["data-consolidation-job"]

echo "=== Glue Tables ==="
aws glue get-tables --database-name data_pipeline_db --query 'TableList[].Name'
# Esperado: ["consolidated_vendas", "consolidated_clientes", "consolidated_cep", "metadata"]
```

## Troubleshooting

### Problema: Terraform apply falha

```bash
# Verificar credenciais
aws sts get-caller-identity

# Verificar permissões
aws iam get-user

# Limpar estado e tentar novamente
terraform destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl
terraform init
terraform apply
```

### Problema: Lambda não consegue salvar no S3

```bash
# Verificar role do Lambda
aws iam get-role --role-name LambdaAPIFetcherRole

# Verificar políticas
aws iam list-attached-role-policies --role-name LambdaAPIFetcherRole

# Ver logs do Lambda
aws logs tail /aws/lambda/cep-api-fetcher --follow
```

### Problema: Glue Job falha

```bash
# Ver logs de erro
aws logs tail /aws-glue/jobs/error --follow

# Ver logs de output
aws logs tail /aws-glue/jobs/output --follow

# Verificar role do Glue
aws iam get-role --role-name GlueDataPipelineRole

# Verificar se arquivos existem no S3
aws s3 ls s3://$RAW_BUCKET/ --recursive
```

### Problema: Athena não encontra tabelas

```bash
# Verificar database
aws glue get-database --name data_pipeline_db

# Executar crawler novamente
aws glue start-crawler --name processed-data-crawler

# Aguardar e verificar
sleep 60
aws glue get-tables --database-name data_pipeline_db
```

## Custos Estimados

### Breakdown Mensal (uso moderado)

| Serviço | Uso | Custo Estimado |
|---------|-----|----------------|
| S3 Storage | 10 GB | $0.23 |
| S3 Requests | 10k requests | $0.05 |
| Lambda | 720 invocações/mês | $0.00 (free tier) |
| Glue Job | 30 execuções x 5 min | $6.60 |
| Glue Crawler | 30 execuções x 1 min | $0.44 |
| Athena | 10 GB scanned | $0.05 |
| **TOTAL** | | **~$7.37/mês** |

### Otimização de Custos

1. **Reduzir frequência de execução**
   - Lambda: 1x/dia ao invés de 1x/hora
   - Glue Job: 1x/dia ao invés de 2x/hora

2. **Lifecycle policies**
   - Mover dados antigos para S3 Glacier
   - Deletar dados temporários após 30 dias

3. **Otimizar Glue Job**
   - Usar job bookmarks
   - Reduzir workers se possível

## Próximos Passos

1. **Personalizar para seu caso de uso**
   - Modificar `glue_jobs/consolidate_data.py`
   - Adicionar suas fontes de dados
   - Ajustar transformações

2. **Adicionar monitoramento**
   - CloudWatch Alarms
   - SNS notifications
   - Dashboard customizado

3. **Implementar CI/CD**
   - GitHub Actions
   - Automated testing
   - Staged deployments

4. **Melhorar segurança**
   - KMS encryption
   - VPC endpoints
   - Fine-grained IAM policies
