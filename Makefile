.PHONY: up down logs validate lint check help

COMPOSE := docker compose -f docker/docker-compose.yml --env-file docker/.env

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

up: ## Start n8n (docker compose up)
	$(COMPOSE) up -d

down: ## Stop n8n (docker compose down)
	$(COMPOSE) down

logs: ## Show n8n logs (follow mode)
	$(COMPOSE) logs -f n8n

validate: ## Validate JSON files (rules + workflow)
	@bash scripts/validate-rules.sh

lint: ## Run linters (yaml, shell, markdown)
	@bash scripts/lint.sh

check: validate lint ## Run all checks (validate + lint)
