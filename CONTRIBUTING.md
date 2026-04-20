# Guia de Contribuição - Pipeline de Dados AWS Glue

Obrigado por considerar contribuir com este projeto! Este guia descreve o
workflow de colaboração, padrões de código, testes e o processo de Pull Request.

## Workflow de Branches

A branch padrão de desenvolvimento é `develop`. Toda contribuição deve seguir
este fluxo:

1. Faça fork e/ou clone do repositório.
2. Atualize a branch base: `git checkout develop && git pull --ff-only origin develop`.
3. Crie uma branch descritiva a partir de `develop`:
   - `feature/<descricao-curta>` — novas funcionalidades
   - `fix/<descricao-curta>` — correções de bugs
   - `chore/<descricao-curta>` — tarefas de manutenção, CI, tooling
   - `docs/<descricao-curta>` — mudanças de documentação
4. Implemente as mudanças, escrevendo ou atualizando testes quando aplicável.
5. Abra um Pull Request para `develop` (ver seção abaixo).
6. Após revisão e merge, delete a branch remota.

> **Nunca** faça push direto em `develop` ou `main`. Todas as mudanças passam
> por Pull Request com revisão.

## Conventional Commits

Use [Conventional Commits](https://www.conventionalcommits.org/pt-br/) para
todas as mensagens de commit. Prefixos aceitos:

- `feat:` — nova funcionalidade
- `fix:` — correção de bug
- `chore:` — tarefas internas (dependências, CI, tooling)
- `docs:` — mudanças apenas em documentação
- `test:` — adição ou correção de testes
- `refactor:` — refatoração sem mudança de comportamento
- `ci:` — mudanças em configuração de CI/CD
- `perf:` — melhorias de performance
- `build:` — mudanças no sistema de build ou dependências externas

Exemplo: `feat(lambda): adiciona retry/backoff na AwesomeAPI`.

## Como Criar PRs

1. Certifique-se de que sua branch está atualizada com `develop` (rebase ou
   merge).
2. Rode `make lint` e `make test` localmente antes de abrir o PR.
3. Abra o PR com **título descritivo** seguindo Conventional Commits.
4. Preencha o template de PR (`.github/pull_request_template.md`):
   - Descreva o que muda e por quê.
   - Marque o tipo de mudança.
   - Vincule a issue relacionada (`Closes #<n>`).
   - Marque os itens do checklist conforme aplicável.
5. Adicione screenshots/logs se ajudar na revisão.
6. Garanta que o CI passe antes de solicitar revisão.

## Processo de Code Review

- Todo PR precisa de **pelo menos 1 aprovação** antes do merge.
- Comentários de revisão devem ser respondidos ou resolvidos pelo autor.
- Mudanças significativas no design devem ser discutidas via issue antes da
  implementação.
- O autor é responsável por manter a branch atualizada com `develop` até o
  merge.

## Branch Protection (Instruções de Configuração)

Para proteger a branch `develop`, um mantenedor deve configurar em
**GitHub → Settings → Branches → Add rule** para `develop`:

- ✔ Require a pull request before merging
  - ✔ Require approvals (1)
  - ✔ Dismiss stale pull request approvals when new commits are pushed
- ✔ Require status checks to pass before merging
  - ✔ Require branches to be up to date before merging
  - Status check obrigatório: `test (3.10)` e `test (3.11)` (CI workflow)
- ✔ Require conversation resolution before merging
- ✔ Include administrators

Configuração equivalente pode ser aplicada em `main` quando houver releases.

## Configuração do Ambiente

```bash
# Dependências (produção + dev)
make install

# Rodar testes
make test

# Formatar código
make format

# Validar estilo
make lint
```

Pré-requisitos: Python 3.10+ e Terraform 1.5+ (para mudanças em
`terraform/`).

## Testes

- Testes ficam em `tests/` e usam `pytest`.
- Use `moto` para mockar serviços AWS; `pytest-mock` para mocks gerais.
- Não dependa de infraestrutura real (AWS, LocalStack, etc.) no CI: use
  mocks ou marcadores `@pytest.mark.skip`/`@pytest.mark.integration` para
  testes que exigem infra.

## Padrões de Código

- Python: `black` (line length 100), `isort` (profile black), `ruff` como
  linter principal.
- Commits passam por `pre-commit` (ativar com `pre-commit install`).
- Evite modificar código gerado ou scripts Glue sem necessidade.

## Segurança

- **Nunca** faça commit de credenciais, access keys, secrets ou tokens.
- Use variáveis de ambiente (`.env.example` como base).
- Para segredos em produção, prefira AWS Secrets Manager ou SSM Parameter
  Store.

## Dúvidas

Abra uma issue usando o template apropriado (`Bug Report` ou
`Feature Request`) ou inicie uma discussão no repositório.
