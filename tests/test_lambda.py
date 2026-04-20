"""Testes para ``lambda/api_fetcher.py``.

Os testes mockam a chamada HTTP para a AwesomeAPI (``urllib3.PoolManager``) e
usam ``moto`` para simular o S3 localmente. Dessa forma nenhum recurso real é
acionado no CI.
"""

from __future__ import annotations

import importlib
import json
import sys
from pathlib import Path
from typing import Any
from unittest.mock import MagicMock

import boto3
import pytest
from moto import mock_aws

LAMBDA_PATH = Path(__file__).resolve().parents[1] / "lambda"


def _load_api_fetcher(monkeypatch: pytest.MonkeyPatch) -> Any:
    """Carrega o módulo ``api_fetcher`` de forma isolada para cada teste."""
    # Garante que importamos do diretório ``lambda`` (nome reservado em Python
    # obriga carga via caminho explícito).
    if str(LAMBDA_PATH) not in sys.path:
        monkeypatch.syspath_prepend(str(LAMBDA_PATH))

    # Remove cache para recarregar com os mocks de cada teste.
    for mod in ("api_fetcher",):
        if mod in sys.modules:
            del sys.modules[mod]

    return importlib.import_module("api_fetcher")


@mock_aws
def test_lambda_handler_salva_dados_no_s3_com_sucesso(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    bucket_name = "raw-test-bucket"
    boto3.client("s3", region_name="us-east-1").create_bucket(Bucket=bucket_name)
    monkeypatch.setenv("RAW_BUCKET", bucket_name)
    monkeypatch.setenv("API_URL", "https://cep.awesomeapi.com.br/json/01001000")

    fake_response = MagicMock()
    fake_response.status = 200
    fake_response.data = json.dumps({"cep": "01001000", "city": "São Paulo", "state": "SP"}).encode(
        "utf-8"
    )

    module = _load_api_fetcher(monkeypatch)
    monkeypatch.setattr(module.http, "request", MagicMock(return_value=fake_response))

    result = module.lambda_handler({}, None)

    assert result["statusCode"] == 200
    body = json.loads(result["body"])
    assert body["bucket"] == bucket_name
    assert body["key"].startswith("api_data/cep_data_")
    assert body["data"]["cep"] == "01001000"
    assert "fetched_at" in body["data"]

    objs = boto3.client("s3", region_name="us-east-1").list_objects_v2(Bucket=bucket_name)
    assert objs["KeyCount"] == 1
    stored = objs["Contents"][0]["Key"]
    assert stored.startswith("api_data/cep_data_") and stored.endswith(".json")


@mock_aws
def test_lambda_handler_retorna_500_quando_api_falha(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    bucket_name = "raw-test-bucket"
    boto3.client("s3", region_name="us-east-1").create_bucket(Bucket=bucket_name)
    monkeypatch.setenv("RAW_BUCKET", bucket_name)

    fake_response = MagicMock()
    fake_response.status = 500
    fake_response.data = b"{}"

    module = _load_api_fetcher(monkeypatch)
    monkeypatch.setattr(module.http, "request", MagicMock(return_value=fake_response))

    result = module.lambda_handler({}, None)

    assert result["statusCode"] == 500
    body = json.loads(result["body"])
    assert "error" in body
    assert "500" in body["error"]


@mock_aws
def test_lambda_handler_retorna_500_quando_json_invalido(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    bucket_name = "raw-test-bucket"
    boto3.client("s3", region_name="us-east-1").create_bucket(Bucket=bucket_name)
    monkeypatch.setenv("RAW_BUCKET", bucket_name)

    fake_response = MagicMock()
    fake_response.status = 200
    fake_response.data = b"isso-nao-eh-json"

    module = _load_api_fetcher(monkeypatch)
    monkeypatch.setattr(module.http, "request", MagicMock(return_value=fake_response))

    result = module.lambda_handler({}, None)

    assert result["statusCode"] == 500
    assert "error" in json.loads(result["body"])


def test_lambda_handler_falha_se_raw_bucket_ausente(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("RAW_BUCKET", raising=False)

    module = _load_api_fetcher(monkeypatch)

    with pytest.raises(KeyError):
        module.lambda_handler({}, None)
