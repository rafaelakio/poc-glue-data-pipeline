"""Configuração global dos testes (pytest).

Define credenciais AWS falsas e região padrão para que bibliotecas como
``boto3`` e ``moto`` consigam operar offline, sem tentar contatar a AWS real.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest

# Garante credenciais fake ANTES de qualquer import de boto3/moto nos testes.
os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")
os.environ.setdefault("AWS_ACCESS_KEY_ID", "testing")
os.environ.setdefault("AWS_SECRET_ACCESS_KEY", "testing")
os.environ.setdefault("AWS_SESSION_TOKEN", "testing")
os.environ.setdefault("AWS_SECURITY_TOKEN", "testing")

# Disponibiliza a raiz do projeto no sys.path para importar ``lambda`` etc.
_REPO_ROOT = Path(__file__).resolve().parents[1]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))


@pytest.fixture(autouse=True)
def _aws_credentials(monkeypatch: pytest.MonkeyPatch) -> None:
    """Força credenciais AWS falsas em cada teste."""
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.setenv("AWS_SESSION_TOKEN", "testing")
    monkeypatch.setenv("AWS_SECURITY_TOKEN", "testing")
