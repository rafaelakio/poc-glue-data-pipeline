# Script de deploy completo do pipeline (PowerShell)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Pipeline AWS Glue - Deploy Completo" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar pré-requisitos
Write-Host "1. Verificando pré-requisitos..." -ForegroundColor Yellow

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI não encontrado. Instale: https://aws.amazon.com/cli/" -ForegroundColor Red
    exit 1
}

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Terraform não encontrado. Instale: https://www.terraform.io/downloads" -ForegroundColor Red
    exit 1
}

Write-Host "✅ AWS CLI: $(aws --version)" -ForegroundColor Green
Write-Host "✅ Terraform: $(terraform --version | Select-Object -First 1)" -ForegroundColor Green
Write-Host ""

# Verificar credenciais AWS
Write-Host "2. Verificando credenciais AWS..." -ForegroundColor Yellow
try {
    $accountId = aws sts get-caller-identity --query Account --output text
    Write-Host "✅ AWS Account: $accountId" -ForegroundColor Green
} catch {
    Write-Host "❌ Credenciais AWS não configuradas. Execute: aws configure" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Deploy infraestrutura
Write-Host "3. Fazendo deploy da infraestrutura..." -ForegroundColor Yellow
Set-Location terraform

if (-not (Test-Path "terraform.tfvars")) {
    Write-Host "📝 Criando terraform.tfvars..." -ForegroundColor Cyan
    Copy-Item terraform.tfvars.example terraform.tfvars
}

terraform init
terraform apply -auto-approve

# Obter outputs
Write-Host ""
Write-Host "4. Obtendo informações dos recursos..." -ForegroundColor Yellow
$rawBucket = terraform output -raw raw_data_bucket
$processedBucket = terraform output -raw processed_data_bucket
$lambdaFunction = terraform output -raw lambda_function_name
$glueJob = terraform output -raw glue_job_name

Write-Host "✅ Raw Bucket: $rawBucket" -ForegroundColor Green
Write-Host "✅ Processed Bucket: $processedBucket" -ForegroundColor Green
Write-Host "✅ Lambda Function: $lambdaFunction" -ForegroundColor Green
Write-Host "✅ Glue Job: $glueJob" -ForegroundColor Green
Write-Host ""

# Upload dados de exemplo
Set-Location ..
Write-Host "5. Fazendo upload dos dados de exemplo..." -ForegroundColor Yellow
aws s3 cp sample_data/vendas.csv "s3://$rawBucket/vendas/vendas.csv"
aws s3 cp sample_data/clientes.json "s3://$rawBucket/clientes/clientes.json"
Write-Host "✅ Dados de exemplo carregados" -ForegroundColor Green
Write-Host ""

# Executar pipeline
Write-Host "6. Executando pipeline..." -ForegroundColor Yellow
Write-Host "   6.1. Invocando Lambda para buscar dados da API..." -ForegroundColor Cyan
aws lambda invoke --function-name $lambdaFunction response.json | Out-Null
Write-Host "   ✅ Lambda executado" -ForegroundColor Green

Write-Host "   6.2. Aguardando 10 segundos..." -ForegroundColor Cyan
Start-Sleep -Seconds 10

Write-Host "   6.3. Iniciando Glue Job..." -ForegroundColor Cyan
$jobRunId = aws glue start-job-run --job-name $glueJob --query 'JobRunId' --output text
Write-Host "   ✅ Glue Job iniciado (Run ID: $jobRunId)" -ForegroundColor Green
Write-Host ""

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  ✅ Deploy Concluído com Sucesso!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📊 Próximos passos:" -ForegroundColor Yellow
Write-Host "   1. Monitorar execução do Glue Job:"
Write-Host "      aws glue get-job-run --job-name $glueJob --run-id $jobRunId"
Write-Host ""
Write-Host "   2. Ver logs:"
Write-Host "      aws logs tail /aws-glue/jobs/output --follow"
Write-Host ""
Write-Host "   3. Após conclusão, executar crawler:"
Write-Host "      aws glue start-crawler --name processed-data-crawler"
Write-Host ""
Write-Host "   4. Consultar dados no Athena:"
Write-Host "      https://console.aws.amazon.com/athena/"
Write-Host ""
