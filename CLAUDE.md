# n8n-kaggle-watcher — Claude Code Configuration

## Project Type

Infrastructure / automation project (not a Kaggle competition project).
No TypeScript, no notebooks, no DS stack.

## Language

All code, comments, commits, and documentation in English.

## Key Files

- `workflows/kaggle-email-watcher.json` — n8n workflow (edit in n8n UI, export as JSON)
- `rules/actions.json` — rules engine configuration (validated by `rules/actions.schema.json`)
- `docker/docker-compose.yml` — self-hosted n8n deployment
- `Makefile` — project commands (`make up`, `make down`, `make validate`, `make logs`)

## Conventions

- **Commits**: Conventional Commits — `<type>(<scope>): <description>`
- **Scopes**: `n8n`, `rules`, `docker`, `ci`, `docs`
- **Branches**: `feat/`, `fix/`, `chore/`, `docs/` — always from `main`
- **PRs**: Follow `CONTRIBUTING.md` template and checklist
- **Labels**: `type:{feature,fix,chore,docs}`, `area:{n8n,rules,docker,ci}`

## Validation

Run `make validate` before committing changes to `rules/` or `workflows/`.

## Do Not

- Edit `workflows/*.json` by hand — always use n8n UI and export
- Commit `.env` files or credentials
- Push directly to `main`
