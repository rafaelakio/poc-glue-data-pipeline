# Pipeline de Dados AWS Glue

Pipeline completo de ETL usando AWS Glue que captura dados de múltiplas fontes (S3 e API), processa e disponibiliza para consulta via Athena.

## 🎯 Características

- ✅ Ingestão automática de dados de API REST
- ✅ Processamento de arquivos CSV e JSON do S3
- ✅ Consolidação e transformação com AWS Glue
- ✅ Armazenamento otimizado em formato Parquet
- ✅ Catalogação automática com Glue Crawler
- ✅ Consultas SQL via Amazon Athena
- ✅ Infraestrutura como código com Terraform
- ✅ Monitoramento e logs com CloudWatch

## 🏗️ Arquitetura

```
┌─────────────┐     ┌─────────────┐
│   S3 Raw    │────▶│             │
│  (2 files)  │     │             │
└─────────────┘     │  AWS Glue   │     ┌──────────────┐
                    │   ETL Job   │────▶│ S3 Processed │
┌─────────────┐     │             │     │   (Parquet)  │
│  API CEP    │────▶│             │     └──────────────┘
│AwesomeAPI   │     │             │            │
└─────────────┘     └─────────────┘            │
                                                ▼
                                         ┌─────────────┐
                                         │   Athena    │
                                         │  (Queries)  │
                                         └─────────────┘
```

## 📦 Componentes

- **S3 Buckets**: Raw data e processed data
- **AWS Glue**: ETL job para processar e consolidar dados
- **Glue Catalog**: Metadata e schema dos dados
- **Athena**: Query engine para análise dos dados
- **Lambda**: Função para capturar dados da API
- **EventBridge**: Agendamento do pipeline
- **IAM**: Roles e políticas de segurança

## 📁 Estrutura do Projeto

```
poc-glue-data-pipeline/
├── terraform/              # Infraestrutura como código
│   ├── main.tf            # Recursos principais (S3, IAM, Lambda)
│   ├── glue.tf            # Recursos Glue (Job, Crawler, Database)
│   ├── variables.tf       # Variáveis configuráveis
│   └── outputs.tf         # Outputs dos recursos
├── glue_jobs/             # Scripts Glue ETL
│   └── consolidate_data.py
├── lambda/                # Funções Lambda
│   └── api_fetcher.py
├── sample_data/           # Dados de exemplo
│   ├── vendas.csv
│   └── clientes.json
├── queries/               # Queries Athena de exemplo
│   └── sample_queries.sql
├── scripts/               # Scripts de automação
│   ├── deploy.sh          # Deploy completo (Linux/Mac)
│   ├── deploy.ps1         # Deploy completo (Windows)
│   ├── monitor.sh         # Monitoramento
│   ├── run-pipeline.sh    # Executar pipeline
│   └── cleanup.sh         # Limpeza de recursos
├── QUICKSTART.md          # Guia rápido
├── DEPLOYMENT.md          # Guia detalhado de deploy
├── ARCHITECTURE.md        # Documentação da arquitetura
└── COMMANDS.md            # Comandos úteis
```

## 🚀 Quick Start

### Opção 1: Script Automatizado (Recomendado)

**Linux/Mac:**
```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

**Windows (PowerShell):**
```powershell
.\scripts\deploy.ps1
```

### Opção 2: Manual

```bash
# 1. Configurar variáveis
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# 2. Deploy da infraestrutura
cd terraform
terraform init
terraform apply

# 3. Upload dos dados de exemplo
cd ..
export RAW_BUCKET=$(cd terraform && terraform output -raw raw_data_bucket)
aws s3 cp sample_data/vendas.csv s3://$RAW_BUCKET/vendas/
aws s3 cp sample_data/clientes.json s3://$RAW_BUCKET/clientes/

# 4. Executar o pipeline
export LAMBDA_FUNCTION=$(cd terraform && terraform output -raw lambda_function_name)
export GLUE_JOB=$(cd terraform && terraform output -raw glue_job_name)

aws lambda invoke --function-name $LAMBDA_FUNCTION response.json
aws glue start-job-run --job-name $GLUE_JOB

# 5. Executar crawler
aws glue start-crawler --name processed-data-crawler
```

## 📊 Consultar Dados

### Via Console AWS
1. Acesse [Amazon Athena](https://console.aws.amazon.com/athena/)
2. Selecione workgroup: `data-pipeline-workgroup`
3. Selecione database: `data_pipeline_db`
4. Execute suas queries

### Queries de Exemplo

```sql
-- Ver todas as vendas
SELECT * FROM consolidated_vendas LIMIT 10;

-- Total de vendas por produto
SELECT produto, COUNT(*) as qtd, SUM(valor) as total
FROM consolidated_vendas
GROUP BY produto
ORDER BY total DESC;

-- Join vendas com clientes
SELECT v.produto, v.valor, c.nome, c.cidade
FROM consolidated_vendas v
LEFT JOIN consolidated_clientes c ON v.cliente_id = c.id;
```

## 💰 Custos Estimados

| Serviço | Uso Mensal | Custo |
|---------|------------|-------|
| S3 Storage | 10 GB | $0.23 |
| Lambda | 720 invocações | $0.00 |
| Glue Job | 30 execuções | $6.60 |
| Athena | 10 GB scanned | $0.05 |
| **TOTAL** | | **~$7/mês** |

## 🔧 Monitoramento

```bash
# Ver status do pipeline
./scripts/monitor.sh

# Ver logs do Lambda
aws logs tail /aws/lambda/cep-api-fetcher --follow

# Ver logs do Glue
aws logs tail /aws-glue/jobs/output --follow
```

## 🧹 Limpeza

```bash
# Linux/Mac
./scripts/cleanup.sh

# Windows
.\scripts\cleanup.ps1

# Ou manual
cd terraform
terraform destroy
```

## 📚 Documentação

- [QUICKSTART.md](QUICKSTART.md) - Guia rápido de início
- [DEPLOYMENT.md](DEPLOYMENT.md) - Guia detalhado de deploy
- [ARCHITECTURE.md](ARCHITECTURE.md) - Arquitetura completa
- [COMMANDS.md](COMMANDS.md) - Referência de comandos

## 🔐 Segurança

- Encryption at rest (S3, Glue)
- IAM roles com least privilege
- VPC endpoints (opcional)
- CloudWatch Logs para auditoria

## 🎓 Pré-requisitos

- AWS CLI v2 configurado
- Terraform >= 1.0
- Conta AWS com permissões adequadas
- Python 3.9+ (para desenvolvimento local)

## 🤝 Contribuindo

Contribuições são bem-vindas! Sinta-se à vontade para abrir issues ou pull requests.

## 📄 Licença

MIT License - veja [LICENSE](LICENSE) para detalhes.
