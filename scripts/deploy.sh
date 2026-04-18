#!/bin/bash
# Script de deploy completo do pipeline

set -e

echo "=========================================="
echo "  Pipeline AWS Glue - Deploy Completo"
echo "=========================================="
echo ""

# Verificar pré-requisitos
echo "1. Verificando pré-requisitos..."

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI não encontrado. Instale: https://aws.amazon.com/cli/"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform não encontrado. Instale: https://www.terraform.io/downloads"
    exit 1
fi

echo "✅ AWS CLI: $(aws --version)"
echo "✅ Terraform: $(terraform --version | head -n1)"
echo ""

# Verificar credenciais AWS
echo "2. Verificando credenciais AWS..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS não configuradas. Execute: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✅ AWS Account: $ACCOUNT_ID"
echo ""

# Deploy infraestrutura
echo "3. Fazendo deploy da infraestrutura..."
cd terraform

if [ ! -f "terraform.tfvars" ]; then
    echo "📝 Criando terraform.tfvars..."
    cp terraform.tfvars.example terraform.tfvars
fi

terraform init
terraform apply -auto-approve

# Obter outputs
echo ""
echo "4. Obtendo informações dos recursos..."
RAW_BUCKET=$(terraform output -raw raw_data_bucket)
PROCESSED_BUCKET=$(terraform output -raw processed_data_bucket)
LAMBDA_FUNCTION=$(terraform output -raw lambda_function_name)
GLUE_JOB=$(terraform output -raw glue_job_name)

echo "✅ Raw Bucket: $RAW_BUCKET"
echo "✅ Processed Bucket: $PROCESSED_BUCKET"
echo "✅ Lambda Function: $LAMBDA_FUNCTION"
echo "✅ Glue Job: $GLUE_JOB"
echo ""

# Upload dados de exemplo
cd ..
echo "5. Fazendo upload dos dados de exemplo..."
aws s3 cp sample_data/vendas.csv s3://$RAW_BUCKET/vendas/vendas.csv
aws s3 cp sample_data/clientes.json s3://$RAW_BUCKET/clientes/clientes.json
echo "✅ Dados de exemplo carregados"
echo ""

# Executar pipeline
echo "6. Executando pipeline..."
echo "   6.1. Invocando Lambda para buscar dados da API..."
aws lambda invoke --function-name $LAMBDA_FUNCTION response.json > /dev/null
echo "   ✅ Lambda executado"

echo "   6.2. Aguardando 10 segundos..."
sleep 10

echo "   6.3. Iniciando Glue Job..."
JOB_RUN_ID=$(aws glue start-job-run --job-name $GLUE_JOB --query 'JobRunId' --output text)
echo "   ✅ Glue Job iniciado (Run ID: $JOB_RUN_ID)"
echo ""

echo "=========================================="
echo "  ✅ Deploy Concluído com Sucesso!"
echo "=========================================="
echo ""
echo "📊 Próximos passos:"
echo "   1. Monitorar execução do Glue Job:"
echo "      aws glue get-job-run --job-name $GLUE_JOB --run-id $JOB_RUN_ID"
echo ""
echo "   2. Ver logs:"
echo "      aws logs tail /aws-glue/jobs/output --follow"
echo ""
echo "   3. Após conclusão, executar crawler:"
echo "      aws glue start-crawler --name processed-data-crawler"
echo ""
echo "   4. Consultar dados no Athena:"
echo "      https://console.aws.amazon.com/athena/"
echo ""
