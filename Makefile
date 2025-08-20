.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help

prod-up: ## Start the production environment
	docker compose -f docker-compose.prod.yaml up -d --build

prod-clean: ## Stop the production environment
	docker compose -f docker-compose.prod.yaml down -v

pre-prod-up: ## Start the pre-production environment
	docker compose -f docker-compose.pre-prod.yaml up -d --build

pre-prod-clean: ## Stop the pre-production environment
	docker compose -f docker-compose.pre-prod.yaml down -v
