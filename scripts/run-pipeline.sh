#!/bin/bash
# Script para executar o pipeline manualmente

set -e

echo "=========================================="
echo "  Executando Pipeline"
echo "=========================================="
echo ""

cd terraform

if [ ! -f "terraform.tfstate" ]; then
    echo "❌ Terraform state não encontrado. Execute deploy primeiro."
    exit 1
fi

LAMBDA_FUNCTION=$(terraform output -raw lambda_function_name)
GLUE_JOB=$(terraform output -raw glue_job_name)

cd ..

# Executar Lambda
echo "1. Executando Lambda para buscar dados da API..."
aws lambda invoke --function-name $LAMBDA_FUNCTION response.json > /dev/null

if [ -f "response.json" ]; then
    echo "✅ Lambda executado com sucesso"
    cat response.json | python -m json.tool
    rm response.json
else
    echo "❌ Erro ao executar Lambda"
    exit 1
fi

echo ""
echo "2. Aguardando 10 segundos..."
sleep 10

# Executar Glue Job
echo ""
echo "3. Executando Glue Job..."
JOB_RUN_ID=$(aws glue start-job-run --job-name $GLUE_JOB --query 'JobRunId' --output text)
echo "✅ Glue Job iniciado"
echo "   Job Run ID: $JOB_RUN_ID"

echo ""
echo "4. Monitorando execução..."
echo "   (Pressione Ctrl+C para sair do monitoramento)"
echo ""

# Monitorar status
while true; do
    STATUS=$(aws glue get-job-run --job-name $GLUE_JOB --run-id $JOB_RUN_ID \
        --query 'JobRun.JobRunState' --output text)
    
    echo "   Status: $STATUS"
    
    if [ "$STATUS" = "SUCCEEDED" ]; then
        echo ""
        echo "✅ Job concluído com sucesso!"
        break
    elif [ "$STATUS" = "FAILED" ] || [ "$STATUS" = "STOPPED" ] || [ "$STATUS" = "ERROR" ]; then
        echo ""
        echo "❌ Job falhou com status: $STATUS"
        echo ""
        echo "Ver logs de erro:"
        echo "aws logs tail /aws-glue/jobs/error --since 10m"
        exit 1
    fi
    
    sleep 10
done

echo ""
echo "5. Executando crawler para catalogar dados..."
aws glue start-crawler --name processed-data-crawler
echo "✅ Crawler iniciado"

echo ""
echo "=========================================="
echo "  ✅ Pipeline Executado com Sucesso!"
echo "=========================================="
echo ""
echo "Próximos passos:"
echo "  1. Aguardar conclusão do crawler (1-2 minutos)"
echo "  2. Consultar dados no Athena"
echo ""
