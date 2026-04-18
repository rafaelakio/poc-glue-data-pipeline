#!/bin/bash
# Script para monitorar o pipeline

echo "=========================================="
echo "  Pipeline AWS Glue - Monitoramento"
echo "=========================================="
echo ""

cd terraform

if [ ! -f "terraform.tfstate" ]; then
    echo "❌ Terraform state não encontrado. Execute deploy primeiro."
    exit 1
fi

GLUE_JOB=$(terraform output -raw glue_job_name)
LAMBDA_FUNCTION=$(terraform output -raw lambda_function_name)

cd ..

# Status do Lambda
echo "📊 Lambda Function: $LAMBDA_FUNCTION"
echo "----------------------------------------"
LAMBDA_STATUS=$(aws lambda get-function --function-name $LAMBDA_FUNCTION --query 'Configuration.[State,LastUpdateStatus]' --output text)
echo "Status: $LAMBDA_STATUS"
echo ""

# Últimas execuções do Glue Job
echo "📊 Glue Job: $GLUE_JOB"
echo "----------------------------------------"
echo "Últimas 5 execuções:"
aws glue get-job-runs --job-name $GLUE_JOB --max-results 5 \
    --query 'JobRuns[].[StartedOn,JobRunState,ExecutionTime]' \
    --output table
echo ""

# Status atual
echo "Status da última execução:"
LAST_RUN=$(aws glue get-job-runs --job-name $GLUE_JOB --max-results 1 \
    --query 'JobRuns[0].[Id,JobRunState,StartedOn,ExecutionTime]' \
    --output text)
echo "$LAST_RUN"
echo ""

# Opções
echo "=========================================="
echo "Opções de monitoramento:"
echo "----------------------------------------"
echo "1. Ver logs do Lambda:"
echo "   aws logs tail /aws/lambda/$LAMBDA_FUNCTION --follow"
echo ""
echo "2. Ver logs do Glue (output):"
echo "   aws logs tail /aws-glue/jobs/output --follow"
echo ""
echo "3. Ver logs do Glue (error):"
echo "   aws logs tail /aws-glue/jobs/error --follow"
echo ""
echo "4. Ver dados processados:"
echo "   aws s3 ls s3://\$(cd terraform && terraform output -raw processed_data_bucket)/ --recursive"
echo ""
