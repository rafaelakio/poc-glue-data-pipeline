# Guia de Contribuição - Pipeline de Dados AWS Glue

Obrigado por considerar contribuir com este projeto! Este guia ajudará você a colaborar de forma efetiva.

## 🤝 Como Contribuir

### 1. Fork e Clone

```bash
git clone https://github.com/seu-usuario/poc-glue-data-pipeline.git
cd poc-glue-data-pipeline
```

### 2. Configure o Ambiente

```bash
# Instalar dependências Python
pip install -r requirements.txt

# Configurar AWS CLI
aws configure

# Instalar Terraform
# Windows: choco install terraform
# Mac: brew install terraform
# Linux: https://www.terraform.io/downloads
```

### 3. Crie uma Branch

```bash
git checkout -b feature/minha-contribuicao
```

### 4. Faça suas Alterações

- Modifique scripts Glue
- Atualize infraestrutura Terraform
- Melhore documentação
- Adicione novos exemplos

### 5. Teste suas Alterações

```bash
# Validar Terraform
cd terraform
terraform init
terraform validate
terraform plan

# Testar scripts Glue localmente (se possível)
python glue_jobs/consolidate_data.py --test

# Validar Python
python -m py_compile glue_jobs/*.py
python -m py_compile lambda/*.py
```

### 6. Commit e Push

```bash
git add .
git commit -m "feat: adiciona [funcionalidade]"
git push origin feature/minha-contribuicao
```

## 📝 Padrões de Código

### Python (Glue Jobs e Lambda)

```python
# Imports organizados
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
import logging

# Configurar logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Funções documentadas
def process_data(glue_context, input_path, output_path):
    """
    Processa dados do S3.
    
    Args:
        glue_context: Contexto do Glue
        input_path: Caminho S3 de entrada
        output_path: Caminho S3 de saída
        
    Returns:
        DynamicFrame: Dados processados
    """
    try:
        # Implementação
        logger.info(f"Processando dados de {input_path}")
        # ...
    except Exception as e:
        logger.error(f"Erro ao processar dados: {e}")
        raise
```

### Terraform

```hcl
# Recursos bem documentados
resource "aws_s3_bucket" "data_bucket" {
  bucket = "${var.project_name}-${var.environment}-data"
  
  tags = {
    Name        = "Data Bucket"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# Variáveis com descrição
variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "data-pipeline"
}

# Outputs úteis
output "bucket_name" {
  description = "Nome do bucket S3"
  value       = aws_s3_bucket.data_bucket.id
}
```

## 🎯 Áreas para Contribuição

### Novos Recursos

- [ ] Suporte a mais formatos de dados (Avro, ORC)
- [ ] Integração com Redshift
- [ ] Integração com RDS
- [ ] Streaming com Kinesis
- [ ] Data quality checks
- [ ] Particionamento automático
- [ ] Compactação de dados
- [ ] Versionamento de dados

### Melhorias em Scripts Glue

- [ ] Otimização de performance
- [ ] Tratamento de erros robusto
- [ ] Logging detalhado
- [ ] Métricas customizadas
- [ ] Validação de dados
- [ ] Transformações adicionais

### Infraestrutura

- [ ] Multi-região
- [ ] Disaster recovery
- [ ] Backup automatizado
- [ ] Cost optimization
- [ ] Security hardening
- [ ] VPC endpoints
- [ ] Encryption at rest/transit

### Documentação

- [ ] Tutoriais passo a passo
- [ ] Diagramas de arquitetura
- [ ] Exemplos de queries Athena
- [ ] Guias de troubleshooting
- [ ] Vídeos explicativos
- [ ] Best practices

### Monitoramento

- [ ] CloudWatch Dashboards
- [ ] Alertas customizados
- [ ] Métricas de custo
- [ ] Métricas de performance
- [ ] Logs centralizados
- [ ] Tracing distribuído

## 📋 Checklist do Pull Request

- [ ] Código Python validado
- [ ] Terraform validado (`terraform validate`)
- [ ] Documentação atualizada
- [ ] Custos estimados documentados
- [ ] Testes realizados (ou marcados como não testado)
- [ ] Não contém credenciais AWS
- [ ] Segue padrões do projeto
- [ ] Commit messages descritivas

## ⚠️ Segurança

### Nunca Commite

- ❌ Access Keys
- ❌ Secret Keys
- ❌ Senhas
- ❌ Tokens
- ❌ Dados sensíveis

### Use

- ✅ Variáveis de ambiente
- ✅ AWS Secrets Manager
- ✅ IAM roles
- ✅ `.env` files (no .gitignore)
- ✅ Terraform variables

### Exemplo Seguro

```python
# ❌ Ruim
db_password = "minha-senha-123"

# ✅ Bom
import os
db_password = os.environ.get('DB_PASSWORD')

# ✅ Melhor ainda
import boto3
secrets_client = boto3.client('secretsmanager')
secret = secrets_client.get_secret_value(SecretId='db-password')
```

## 💰 Custos

### Documentar Custos

Sempre documente custos estimados:

```markdown
## 💰 Custos Estimados

| Recurso | Uso | Custo Mensal |
|---------|-----|--------------|
| S3 Storage | 100 GB | $2.30 |
| Glue Job | 30 runs x 10 DPU | $13.20 |
| Athena | 100 GB scanned | $0.50 |
| **TOTAL** | | **~$16/mês** |

**Free Tier**: Não aplicável para Glue

**Recomendação**: Use tags para rastreamento de custos
```

### Otimização de Custos

- Use particionamento no S3
- Comprima dados (Parquet, Snappy)
- Configure lifecycle policies
- Use Spot instances quando possível
- Monitore custos com Cost Explorer

## 🧪 Testando

### Testes Locais

```bash
# Validar Python
python -m py_compile glue_jobs/*.py

# Validar Terraform
cd terraform
terraform init
terraform validate
terraform plan -out=plan.tfplan

# Testar queries Athena localmente (com DuckDB)
pip install duckdb
python scripts/test_queries.py
```

### Testes na AWS

```bash
# Usar conta/região de testes
export AWS_PROFILE=test
export AWS_DEFAULT_REGION=us-east-1

# Deploy em ambiente de teste
cd terraform
terraform workspace new test
terraform apply -var="environment=test"

# Executar pipeline de teste
./scripts/run-pipeline.sh

# Limpar após testes
terraform destroy -var="environment=test"
```

## 🐛 Reportando Bugs

```markdown
**Descrição**
Descrição clara do problema.

**Componente Afetado**
- [ ] Glue Job
- [ ] Lambda Function
- [ ] Terraform
- [ ] Athena Query
- [ ] Outro: ___

**Como Reproduzir**
1. Execute `terraform apply`
2. Execute `aws glue start-job-run...`
3. Observe erro...

**Logs**
```
Cole logs relevantes aqui
```

**Ambiente**
- Região AWS: [us-east-1]
- Terraform version: [1.5.0]
- Python version: [3.9]
- AWS CLI version: [2.x]
```

## 💡 Sugerindo Melhorias

```markdown
**Funcionalidade**
Nome da funcionalidade proposta.

**Problema que Resolve**
Descrição do problema ou necessidade.

**Solução Proposta**
Como deveria funcionar.

**Impacto em Custos**
Estimativa de impacto nos custos.

**Alternativas**
Outras abordagens consideradas.
```

## 📚 Recursos para Contribuidores

### AWS Glue

- [AWS Glue Documentation](https://docs.aws.amazon.com/glue/)
- [Glue Best Practices](https://docs.aws.amazon.com/glue/latest/dg/best-practices.html)
- [PySpark Documentation](https://spark.apache.org/docs/latest/api/python/)
- [Glue Transforms](https://docs.aws.amazon.com/glue/latest/dg/built-in-transforms.html)

### Terraform

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Terraform Style Guide](https://www.terraform.io/docs/language/syntax/style.html)

### Athena

- [Athena Documentation](https://docs.aws.amazon.com/athena/)
- [Presto SQL Functions](https://prestodb.io/docs/current/functions.html)
- [Athena Performance Tuning](https://docs.aws.amazon.com/athena/latest/ug/performance-tuning.html)

## 🎓 Dicas para Contribuidores

### 1. Entenda o Pipeline

Antes de contribuir, entenda o fluxo:
```
API/S3 → Lambda → S3 Raw → Glue Job → S3 Processed → Crawler → Athena
```

### 2. Teste Localmente Quando Possível

- Valide Python antes de fazer deploy
- Use `terraform plan` antes de `apply`
- Teste queries SQL localmente

### 3. Documente Bem

- Explique o "por quê", não só o "como"
- Inclua exemplos de uso
- Documente custos
- Adicione diagramas

### 4. Pense em Custos

- Sempre considere impacto nos custos
- Documente estimativas
- Sugira otimizações
- Use tags para rastreamento

## 🔄 Processo de Review

1. **Automated Checks**: Validação automática
2. **Code Review**: Revisão por mantenedores
3. **Testing**: Testes em ambiente de staging
4. **Documentation**: Verificação de docs
5. **Approval**: Aprovação e merge

## 🙏 Agradecimentos

Obrigado por contribuir! Sua ajuda torna este projeto melhor para todos que estão aprendendo sobre pipelines de dados na AWS.

Cada contribuição, por menor que seja, é valiosa! 🚀

