# Arquitetura do Pipeline de Dados

## Visão Geral

Este projeto implementa um pipeline ETL completo na AWS usando serviços serverless e gerenciados.

## Diagrama de Arquitetura

```
┌─────────────────────────────────────────────────────────────────┐
│                         DATA SOURCES                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐     │
│  │  vendas.csv  │    │clientes.json │    │   CEP API    │     │
│  │   (S3 Raw)   │    │  (S3 Raw)    │    │AwesomeAPI    │     │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘     │
│         │                   │                    │              │
└─────────┼───────────────────┼────────────────────┼──────────────┘
          │                   │                    │
          │                   │                    │
          │                   │            ┌───────▼────────┐
          │                   │            │  Lambda         │
          │                   │            │  API Fetcher    │
          │                   │            │  (Scheduled)    │
          │                   │            └───────┬────────┘
          │                   │                    │
          └───────────────────┴────────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │   S3 Raw Bucket    │
                    │  (Landing Zone)    │
                    └─────────┬──────────┘
                              │
                    ┌─────────▼──────────┐
                    │   AWS Glue Job     │
                    │  (ETL Process)     │
                    │  - Read CSV/JSON   │
                    │  - Transform       │
                    │  - Consolidate     │
                    └─────────┬──────────┘
                              │
                    ┌─────────▼──────────┐
                    │ S3 Processed       │
                    │ (Parquet Format)   │
                    │ Partitioned        │
                    └─────────┬──────────┘
                              │
                    ┌─────────▼──────────┐
                    │  Glue Crawler      │
                    │  (Auto Catalog)    │
                    └─────────┬──────────┘
                              │
                    ┌─────────▼──────────┐
                    │  Glue Catalog      │
                    │  (Metadata Store)  │
                    └─────────┬──────────┘
                              │
                    ┌─────────▼──────────┐
                    │   Amazon Athena    │
                    │  (SQL Queries)     │
                    └────────────────────┘
```

## Componentes Principais

### 1. Camada de Ingestão

#### Lambda Function (api_fetcher.py)
- **Propósito**: Buscar dados da API CEP periodicamente
- **Trigger**: EventBridge (a cada 1 hora)
- **Output**: JSON no S3 Raw Bucket
- **Runtime**: Python 3.11

#### S3 Raw Bucket
- **Propósito**: Landing zone para dados brutos
- **Estrutura**:
  ```
  s3://glue-raw-data-{account-id}/
  ├── vendas/
  │   └── vendas.csv
  ├── clientes/
  │   └── clientes.json
  └── api_data/
      └── cep_data_YYYYMMDD_HHMMSS.json
  ```

### 2. Camada de Processamento

#### AWS Glue Job (consolidate_data.py)
- **Propósito**: ETL e consolidação de dados
- **Trigger**: EventBridge (a cada 2 horas)
- **Processamento**:
  1. Lê CSV de vendas
  2. Lê JSON de clientes
  3. Lê JSON da API CEP
  4. Adiciona metadados (timestamp, source)
  5. Converte para Parquet
  6. Particiona por data de processamento
- **Workers**: 2x G.1X (4 DPU total)
- **Glue Version**: 4.0

#### S3 Processed Bucket
- **Propósito**: Armazenamento de dados processados
- **Formato**: Parquet (otimizado para queries)
- **Estrutura**:
  ```
  s3://glue-processed-data-{account-id}/
  ├── consolidated/
  │   ├── vendas/
  │   │   └── processed_at=2024-01-15T10:00:00/
  │   ├── clientes/
  │   │   └── processed_at=2024-01-15T10:00:00/
  │   └── cep/
  │       └── processed_at=2024-01-15T10:00:00/
  └── metadata/
      └── job_execution_info.parquet
  ```

### 3. Camada de Catalogação

#### Glue Crawler
- **Propósito**: Descobrir schema e criar tabelas automaticamente
- **Trigger**: Após sucesso do Glue Job
- **Output**: Tabelas no Glue Catalog

#### Glue Catalog Database
- **Nome**: data_pipeline_db
- **Tabelas**:
  - `consolidated_vendas`
  - `consolidated_clientes`
  - `consolidated_cep`
  - `metadata`

### 4. Camada de Consulta

#### Amazon Athena
- **Propósito**: Query engine SQL serverless
- **Workgroup**: data-pipeline-workgroup
- **Output**: S3 Athena Results Bucket
- **Formato de Query**: SQL padrão (Presto)

## Fluxo de Dados

### Fluxo Principal

1. **Ingestão Contínua**
   - Lambda executa a cada hora
   - Busca dados da API CEP
   - Salva JSON no S3 Raw

2. **Processamento Batch**
   - Glue Job executa a cada 2 horas
   - Lê todos os dados do S3 Raw
   - Transforma e consolida
   - Salva Parquet no S3 Processed

3. **Catalogação Automática**
   - Crawler executa após Glue Job
   - Atualiza schema no Glue Catalog
   - Torna dados disponíveis para Athena

4. **Consulta Ad-hoc**
   - Usuário executa queries no Athena
   - Athena lê Parquet do S3
   - Resultados salvos no S3 Athena Results

## Segurança

### IAM Roles

#### GlueDataPipelineRole
- Permissões:
  - Leitura/Escrita em S3 (raw, processed, scripts)
  - Acesso ao Glue Catalog
  - CloudWatch Logs

#### LambdaAPIFetcherRole
- Permissões:
  - Escrita em S3 Raw Bucket
  - CloudWatch Logs

### Encryption
- S3: Server-side encryption (SSE-S3)
- Glue: Encryption at rest
- Athena: Encryption de resultados

## Monitoramento

### CloudWatch Metrics
- Lambda invocations e errors
- Glue Job duration e DPU usage
- S3 bucket size e requests

### CloudWatch Logs
- `/aws/lambda/cep-api-fetcher`
- `/aws-glue/jobs/output`
- `/aws-glue/jobs/error`

### Alertas Recomendados
- Lambda failures > 3 em 5 minutos
- Glue Job duration > 30 minutos
- Glue Job failures

## Otimizações

### Performance
- Formato Parquet (compressão Snappy)
- Particionamento por data
- Predicate pushdown no Athena
- Columnar storage

### Custos
- Job bookmarks (evita reprocessamento)
- Lifecycle policies no S3
- Athena query result expiration
- Glue Job auto-scaling

## Escalabilidade

### Limites Atuais
- Lambda: 1 execução concorrente
- Glue Job: 1 execução concorrente
- Workers: 2x G.1X

### Escalar Para Produção
1. Aumentar workers do Glue (4-10)
2. Habilitar auto-scaling
3. Adicionar DLQ (Dead Letter Queue)
4. Implementar retry logic
5. Adicionar data quality checks
6. Configurar backup cross-region

## Extensões Futuras

1. **Data Quality**
   - AWS Glue Data Quality rules
   - Validação de schema
   - Detecção de anomalias

2. **Orquestração**
   - AWS Step Functions
   - Workflow complexo
   - Error handling avançado

3. **Real-time**
   - Kinesis Data Streams
   - Glue Streaming
   - Near real-time analytics

4. **Machine Learning**
   - SageMaker integration
   - Feature store
   - Model training pipeline

5. **Governança**
   - AWS Lake Formation
   - Fine-grained access control
   - Data lineage tracking
