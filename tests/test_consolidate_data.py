"""Testes estáticos / de contrato para ``glue_jobs/consolidate_data.py``.

O script Glue depende de ``awsglue`` e de um ``SparkContext`` real, que não
existem no ambiente de CI padrão. Os testes abaixo validam contratos
importantes do script (estrutura, argumentos esperados, caminhos de escrita)
sem precisar executar a SparkSession.
"""

from __future__ import annotations

import ast
from pathlib import Path

import pytest

GLUE_JOB_PATH = Path(__file__).resolve().parents[1] / "glue_jobs" / "consolidate_data.py"


@pytest.fixture(scope="module")
def source_code() -> str:
    assert GLUE_JOB_PATH.is_file(), f"Arquivo não encontrado: {GLUE_JOB_PATH}"
    return GLUE_JOB_PATH.read_text(encoding="utf-8")


def test_glue_job_e_codigo_python_valido(source_code: str) -> None:
    """O script Glue deve ser sintaticamente válido."""
    ast.parse(source_code)


def test_glue_job_define_argumentos_esperados(source_code: str) -> None:
    """O job deve usar ``getResolvedOptions`` com os argumentos documentados."""
    esperados = ["JOB_NAME", "RAW_BUCKET", "PROCESSED_BUCKET", "DATABASE_NAME"]
    for nome in esperados:
        assert (
            f"'{nome}'" in source_code or f'"{nome}"' in source_code
        ), f"Argumento Glue ausente: {nome}"


def test_glue_job_le_todas_as_fontes(source_code: str) -> None:
    """Confere que o job lê vendas, clientes e dados da API CEP."""
    for caminho in ("vendas/", "clientes/", "api_data/"):
        assert caminho in source_code, f"Leitura ausente do caminho: {caminho}"


def test_glue_job_escreve_em_parquet_particionado(source_code: str) -> None:
    """Confere que os datasets são gravados em Parquet particionado por ``processed_at``."""
    assert ".parquet(" in source_code
    assert 'partitionBy("processed_at")' in source_code


def test_glue_job_commita_ao_final(source_code: str) -> None:
    """O job deve finalizar com ``job.commit()`` (boas práticas Glue)."""
    assert "job.commit()" in source_code


def test_glue_job_registra_metadata(source_code: str) -> None:
    """O job deve persistir metadata de execução."""
    assert "metadata/" in source_code
    assert '"status": "SUCCESS"' in source_code
