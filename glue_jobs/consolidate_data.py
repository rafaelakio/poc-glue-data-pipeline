import sys
from datetime import datetime

import boto3
from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.functions import *
from pyspark.sql.types import *

# Inicializar contextos
args = getResolvedOptions(sys.argv, ["JOB_NAME", "RAW_BUCKET", "PROCESSED_BUCKET", "DATABASE_NAME"])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

# Configurações
RAW_BUCKET = args["RAW_BUCKET"]
PROCESSED_BUCKET = args["PROCESSED_BUCKET"]
DATABASE_NAME = args["DATABASE_NAME"]

print("Iniciando job de consolidação...")
print(f"Raw Bucket: {RAW_BUCKET}")
print(f"Processed Bucket: {PROCESSED_BUCKET}")

# 1. Ler arquivo CSV de vendas
print("Lendo arquivo de vendas...")
try:
    vendas_path = f"s3://{RAW_BUCKET}/vendas/"
    vendas_df = spark.read.option("header", "true").option("inferSchema", "true").csv(vendas_path)
    print(f"Vendas carregadas: {vendas_df.count()} registros")
except Exception as e:
    print(f"Erro ao ler vendas: {e}")
    vendas_df = spark.createDataFrame([], StructType([]))

# 2. Ler arquivo JSON de clientes
print("Lendo arquivo de clientes...")
try:
    clientes_path = f"s3://{RAW_BUCKET}/clientes/"
    clientes_df = spark.read.json(clientes_path)
    print(f"Clientes carregados: {clientes_df.count()} registros")
except Exception as e:
    print(f"Erro ao ler clientes: {e}")
    clientes_df = spark.createDataFrame([], StructType([]))

# 3. Ler dados da API CEP
print("Lendo dados da API CEP...")
try:
    cep_path = f"s3://{RAW_BUCKET}/api_data/"
    cep_df = spark.read.json(cep_path)
    print(f"Dados CEP carregados: {cep_df.count()} registros")
except Exception as e:
    print(f"Erro ao ler dados CEP: {e}")
    cep_df = spark.createDataFrame([], StructType([]))

# 4. Consolidar dados
print("Consolidando dados...")

# Adicionar timestamp de processamento
current_timestamp = datetime.now().isoformat()

# Processar vendas
if vendas_df.count() > 0:
    vendas_df = vendas_df.withColumn("source", lit("vendas")).withColumn(
        "processed_at", lit(current_timestamp)
    )

# Processar clientes
if clientes_df.count() > 0:
    clientes_df = clientes_df.withColumn("source", lit("clientes")).withColumn(
        "processed_at", lit(current_timestamp)
    )

# Processar CEP
if cep_df.count() > 0:
    cep_df = cep_df.withColumn("source", lit("api_cep")).withColumn(
        "processed_at", lit(current_timestamp)
    )

# 5. Criar DataFrame consolidado
# Aqui você pode fazer joins ou simplesmente salvar separadamente
# Exemplo: Join vendas com clientes se houver campo comum

consolidated_data = []

if vendas_df.count() > 0:
    consolidated_data.append(vendas_df)

if clientes_df.count() > 0:
    consolidated_data.append(clientes_df)

if cep_df.count() > 0:
    consolidated_data.append(cep_df)

# 6. Salvar dados processados em formato Parquet particionado
print("Salvando dados consolidados...")

# Salvar vendas
if vendas_df.count() > 0:
    vendas_output = f"s3://{PROCESSED_BUCKET}/consolidated/vendas/"
    vendas_df.write.mode("overwrite").partitionBy("processed_at").parquet(vendas_output)
    print(f"Vendas salvas em: {vendas_output}")

# Salvar clientes
if clientes_df.count() > 0:
    clientes_output = f"s3://{PROCESSED_BUCKET}/consolidated/clientes/"
    clientes_df.write.mode("overwrite").partitionBy("processed_at").parquet(clientes_output)
    print(f"Clientes salvos em: {clientes_output}")

# Salvar CEP
if cep_df.count() > 0:
    cep_output = f"s3://{PROCESSED_BUCKET}/consolidated/cep/"
    cep_df.write.mode("overwrite").partitionBy("processed_at").parquet(cep_output)
    print(f"Dados CEP salvos em: {cep_output}")

# 7. Criar view consolidada (opcional)
# Se você quiser uma única tabela com todos os dados
if len(consolidated_data) > 0:
    # Aqui você pode fazer transformações mais complexas
    # Por exemplo, normalizar schemas e unir tudo
    print("Criando view consolidada...")

    # Exemplo simples: salvar metadados
    metadata = spark.createDataFrame(
        [
            {
                "job_name": args["JOB_NAME"],
                "execution_time": current_timestamp,
                "vendas_count": vendas_df.count() if vendas_df.count() > 0 else 0,
                "clientes_count": clientes_df.count() if clientes_df.count() > 0 else 0,
                "cep_count": cep_df.count() if cep_df.count() > 0 else 0,
                "status": "SUCCESS",
            }
        ]
    )

    metadata_output = f"s3://{PROCESSED_BUCKET}/metadata/"
    metadata.write.mode("append").parquet(metadata_output)
    print(f"Metadata salva em: {metadata_output}")

print("Job de consolidação concluído com sucesso!")

job.commit()
