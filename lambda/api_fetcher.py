import json
import os
from datetime import datetime

import boto3
import urllib3

s3_client = boto3.client("s3")
http = urllib3.PoolManager()


def lambda_handler(event, context):
    """
    Lambda function para buscar dados da API CEP e salvar no S3
    """

    raw_bucket = os.environ["RAW_BUCKET"]
    api_url = os.environ.get("API_URL", "https://cep.awesomeapi.com.br/json/01001000")

    print(f"Buscando dados da API: {api_url}")

    try:
        # Fazer requisição para a API
        response = http.request("GET", api_url)

        if response.status != 200:
            raise Exception(f"API retornou status {response.status}")

        # Parse do JSON
        data = json.loads(response.data.decode("utf-8"))
        print(f"Dados recebidos: {data}")

        # Adicionar timestamp
        data["fetched_at"] = datetime.now().isoformat()

        # Gerar nome do arquivo com timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        file_key = f"api_data/cep_data_{timestamp}.json"

        # Salvar no S3
        s3_client.put_object(
            Bucket=raw_bucket,
            Key=file_key,
            Body=json.dumps(data, ensure_ascii=False),
            ContentType="application/json",
        )

        print(f"Dados salvos em s3://{raw_bucket}/{file_key}")

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": "Dados da API salvos com sucesso",
                    "bucket": raw_bucket,
                    "key": file_key,
                    "data": data,
                }
            ),
        }

    except Exception as e:
        print(f"Erro ao buscar dados da API: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Erro ao buscar dados da API", "error": str(e)}),
        }
