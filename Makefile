.PHONY: up down logs validate lint check install-watchdog uninstall-watchdog help

COMPOSE := docker compose -f docker/docker-compose.yml --env-file docker/.env

WATCHDOG_BIN := $(HOME)/.local/bin/n8n-watchdog
SYSTEMD_USER_DIR := $(HOME)/.config/systemd/user
WATCHDOG_ENV_DIR := $(HOME)/.config/n8n-watchdog

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

install-watchdog: ## Install external watchdog (user systemd timer)
	@install -d $(dir $(WATCHDOG_BIN)) $(SYSTEMD_USER_DIR)
	@install -m 755 scripts/watchdog.sh $(WATCHDOG_BIN)
	@install -m 644 scripts/n8n-watchdog.service $(SYSTEMD_USER_DIR)/n8n-watchdog.service
	@install -m 644 scripts/n8n-watchdog.timer $(SYSTEMD_USER_DIR)/n8n-watchdog.timer
	@systemctl --user daemon-reload
	@systemctl --user enable --now n8n-watchdog.timer
	@echo "✓ Watchdog installed and timer enabled."
	@echo "  Status:    systemctl --user status n8n-watchdog.timer"
	@echo "  Last run:  systemctl --user status n8n-watchdog.service"
	@echo "  Manual:    $(WATCHDOG_BIN)"
	@if [ ! -f "$(WATCHDOG_ENV_DIR)/env" ]; then \
		echo "⚠ Create $(WATCHDOG_ENV_DIR)/env with TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID and STATE_DIR."; \
		echo "  See docs/setup-n8n.md → External Watchdog."; \
	fi
	@if [ "$$(loginctl show-user "$$USER" -p Linger --value 2>/dev/null)" != "yes" ]; then \
		echo "⚠ Linger is not enabled for $$USER — the user systemd manager (and this timer) only runs while you are logged in."; \
		echo "  After a reboot without an interactive login, the watchdog will be silent until next login."; \
		echo "  Enable lingering once (requires sudo): sudo loginctl enable-linger $$USER"; \
	fi

uninstall-watchdog: ## Uninstall external watchdog (keeps env file)
	-@systemctl --user disable --now n8n-watchdog.timer 2>/dev/null || true
	-@rm -f $(SYSTEMD_USER_DIR)/n8n-watchdog.service $(SYSTEMD_USER_DIR)/n8n-watchdog.timer
	-@rm -f $(WATCHDOG_BIN)
	@systemctl --user daemon-reload
	@echo "✓ Watchdog uninstalled. Env file at $(WATCHDOG_ENV_DIR)/env left in place."
