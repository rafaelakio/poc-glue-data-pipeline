.PHONY: install test lint format clean

install:
	pip install -r requirements.txt
	pip install -r requirements-dev.txt
	pre-commit install || true

test:
	pytest --cov --cov-report=term-missing

lint:
	ruff check .
	black --check .
	isort --check-only .

format:
	black .
	isort .
	ruff check --fix .

clean:
	find . -type d -name __pycache__ -exec rm -rf {} + || true
	rm -rf .pytest_cache .mypy_cache .ruff_cache htmlcov .coverage coverage.xml
