#!/bin/bash
# Script para limpar todos os recursos

set -e

echo "=========================================="
echo "  Pipeline AWS Glue - Limpeza"
echo "=========================================="
echo ""

read -p "⚠️  Isso vai deletar TODOS os recursos. Continuar? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Operação cancelada"
    exit 0
fi

echo ""
echo "1. Obtendo informações dos buckets..."
cd terraform

if [ ! -f "terraform.tfstate" ]; then
    echo "❌ Terraform state não encontrado. Nada para limpar."
    exit 0
fi

RAW_BUCKET=$(terraform output -raw raw_data_bucket 2>/dev/null || echo "")
PROCESSED_BUCKET=$(terraform output -raw processed_data_bucket 2>/dev/null || echo "")
SCRIPTS_BUCKET=$(terraform output -raw glue_scripts_bucket 2>/dev/null || echo "")
ATHENA_BUCKET=$(terraform output -raw athena_results_bucket 2>/dev/null || echo "")

# Esvaziar buckets
echo ""
echo "2. Esvaziando buckets S3..."

if [ ! -z "$RAW_BUCKET" ]; then
    echo "   Esvaziando $RAW_BUCKET..."
    aws s3 rm s3://$RAW_BUCKET --recursive 2>/dev/null || true
    echo "   ✅ Raw bucket esvaziado"
fi

if [ ! -z "$PROCESSED_BUCKET" ]; then
    echo "   Esvaziando $PROCESSED_BUCKET..."
    aws s3 rm s3://$PROCESSED_BUCKET --recursive 2>/dev/null || true
    echo "   ✅ Processed bucket esvaziado"
fi

if [ ! -z "$SCRIPTS_BUCKET" ]; then
    echo "   Esvaziando $SCRIPTS_BUCKET..."
    aws s3 rm s3://$SCRIPTS_BUCKET --recursive 2>/dev/null || true
    echo "   ✅ Scripts bucket esvaziado"
fi

if [ ! -z "$ATHENA_BUCKET" ]; then
    echo "   Esvaziando $ATHENA_BUCKET..."
    aws s3 rm s3://$ATHENA_BUCKET --recursive 2>/dev/null || true
    echo "   ✅ Athena bucket esvaziado"
fi

# Destruir infraestrutura
echo ""
echo "3. Destruindo infraestrutura..."
terraform destroy -auto-approve

echo ""
echo "=========================================="
echo "  ✅ Limpeza Concluída!"
echo "=========================================="
echo ""
