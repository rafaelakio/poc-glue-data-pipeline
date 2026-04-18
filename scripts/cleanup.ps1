# Script para limpar todos os recursos (PowerShell)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Pipeline AWS Glue - Limpeza" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$confirm = Read-Host "⚠️  Isso vai deletar TODOS os recursos. Continuar? (yes/no)"

if ($confirm -ne "yes") {
    Write-Host "❌ Operação cancelada" -ForegroundColor Red
    exit 0
}

Write-Host ""
Write-Host "1. Obtendo informações dos buckets..." -ForegroundColor Yellow
Set-Location terraform

if (-not (Test-Path "terraform.tfstate")) {
    Write-Host "❌ Terraform state não encontrado. Nada para limpar." -ForegroundColor Red
    exit 0
}

$rawBucket = terraform output -raw raw_data_bucket 2>$null
$processedBucket = terraform output -raw processed_data_bucket 2>$null
$scriptsBucket = terraform output -raw glue_scripts_bucket 2>$null
$athenaBucket = terraform output -raw athena_results_bucket 2>$null

# Esvaziar buckets
Write-Host ""
Write-Host "2. Esvaziando buckets S3..." -ForegroundColor Yellow

if ($rawBucket) {
    Write-Host "   Esvaziando $rawBucket..." -ForegroundColor Cyan
    aws s3 rm "s3://$rawBucket" --recursive 2>$null
    Write-Host "   ✅ Raw bucket esvaziado" -ForegroundColor Green
}

if ($processedBucket) {
    Write-Host "   Esvaziando $processedBucket..." -ForegroundColor Cyan
    aws s3 rm "s3://$processedBucket" --recursive 2>$null
    Write-Host "   ✅ Processed bucket esvaziado" -ForegroundColor Green
}

if ($scriptsBucket) {
    Write-Host "   Esvaziando $scriptsBucket..." -ForegroundColor Cyan
    aws s3 rm "s3://$scriptsBucket" --recursive 2>$null
    Write-Host "   ✅ Scripts bucket esvaziado" -ForegroundColor Green
}

if ($athenaBucket) {
    Write-Host "   Esvaziando $athenaBucket..." -ForegroundColor Cyan
    aws s3 rm "s3://$athenaBucket" --recursive 2>$null
    Write-Host "   ✅ Athena bucket esvaziado" -ForegroundColor Green
}

# Destruir infraestrutura
Write-Host ""
Write-Host "3. Destruindo infraestrutura..." -ForegroundColor Yellow
terraform destroy -auto-approve

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  ✅ Limpeza Concluída!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
