# Supabase E-Commerce Analytics Makefile
# ----------------------------------
.PHONY: help setup venv install data-load dbt-init dbt-run dbt-test dbt-docs docker-dev docker-prod docker-down db-reset clean test lint docs
.DEFAULT_GOAL := help

# Project directories
SRC_DIR := src
DBT_DIR := $(SRC_DIR)/dbt_project
ETL_DIR := $(SRC_DIR)/etl
DATA_DIR := $(SRC_DIR)/data
VENV_DIR := venv
DOCS_DIR := docs
DOCKER_DIR := docker

# Python settings
PYTHON := python3
PIP := $(VENV_DIR)/bin/pip
PYTHON_VENV := $(VENV_DIR)/bin/python
DBT := $(VENV_DIR)/bin/dbt

# Docker settings
DOCKER_COMPOSE := docker compose
DOCKER_DEV_FILE := $(DOCKER_DIR)/docker-compose.dev.yml
DOCKER_PROD_FILE := $(DOCKER_DIR)/docker-compose.prod.yml

# Colors for terminal output
BOLD := \033[1m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BOLD)Supabase E-Commerce Analytics$(NC)"
	@echo "$(BOLD)-----------------------------------------$(NC)"
	@echo "Usage: make [target]"
	@echo ""
	@echo "$(BOLD)Available targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

# ====================
# Environment Setup
# ====================

setup: venv install ## Set up the development environment

venv: ## Create virtual environment if it doesn't exist
	@echo "$(BOLD)Creating virtual environment...$(NC)"
	@if [ ! -d "$(VENV_DIR)" ]; then \
		$(PYTHON) -m venv $(VENV_DIR); \
		echo "$(GREEN)Virtual environment created at $(VENV_DIR)$(NC)"; \
	else \
		echo "$(YELLOW)Virtual environment already exists at $(VENV_DIR)$(NC)"; \
	fi

install: venv ## Install dependencies
	@echo "$(BOLD)Installing dependencies...$(NC)"
	@$(PIP) install --upgrade pip
	@$(PIP) install -r requirements.txt
	@echo "$(GREEN)Dependencies installed successfully!$(NC)"

# ====================
# DBT Commands
# ====================

dbt-init: ## Initialize dbt project (if not already initialized)
	@echo "$(BOLD)Initializing dbt project...$(NC)"
	@if [ ! -f "$(DBT_DIR)/dbt_project.yml" ]; then \
		mkdir -p $(SRC_DIR); \
		cd $(SRC_DIR) && ../$(VENV_DIR)/bin/dbt init dbt_project; \
		echo "$(GREEN)DBT project initialized in $(DBT_DIR)$(NC)"; \
	else \
		echo "$(YELLOW)DBT project already exists at $(DBT_DIR)$(NC)"; \
	fi

dbt-run: ## Run dbt models
	@echo "$(BOLD)Running dbt models...$(NC)"
	@cd $(DBT_DIR) && ../../$(DBT) run

dbt-build: ## Build dbt models (run + test)
	@echo "$(BOLD)Building dbt models...$(NC)"
	@cd $(DBT_DIR) && ../../$(DBT) build

dbt-test: ## Run dbt tests
	@echo "$(BOLD)Running dbt tests...$(NC)"
	@cd $(DBT_DIR) && ../../$(DBT) test

dbt-docs: ## Generate dbt documentation
	@echo "$(BOLD)Generating dbt documentation...$(NC)"
	@cd $(DBT_DIR) && ../../$(DBT) docs generate
	@echo "$(GREEN)DBT docs generated!$(NC)"

dbt-docs-serve: dbt-docs ## Generate and serve dbt documentation
	@echo "$(BOLD)Serving dbt documentation...$(NC)"
	@cd $(DBT_DIR) && ../../$(DBT) docs serve

dbt-clean: ## Clean dbt artifacts
	@echo "$(BOLD)Cleaning dbt artifacts...$(NC)"
	@cd $(DBT_DIR) && ../../$(DBT) clean
	@echo "$(GREEN)DBT artifacts cleaned!$(NC)"

dbt-deps: ## Install dbt dependencies
	@echo "$(BOLD)Installing dbt dependencies...$(NC)"
	@cd $(DBT_DIR) && ../../$(DBT) deps
	@echo "$(GREEN)DBT dependencies installed!$(NC)"

# ====================
# Docker Commands
# ====================

docker-dev: ## Start development environment with docker-compose
	@echo "$(BOLD)Starting development services...$(NC)"
	@echo "$(BOLD)Loading environment variables from .env.dev...$(NC)"
	@export $$(grep -v '^#' .env.dev | xargs) && $(DOCKER_COMPOSE) -f $(DOCKER_DEV_FILE) up -d
	@echo "$(GREEN)Development services started!$(NC)"

docker-prod: ## Start production environment with docker-compose
	@echo "$(BOLD)Starting production services...$(NC)"
	@$(DOCKER_COMPOSE) -f $(DOCKER_PROD_FILE) up -d
	@echo "$(GREEN)Production services started!$(NC)"

docker-down: ## Stop all docker services
	@echo "$(BOLD)Stopping all services...$(NC)"
	@$(DOCKER_COMPOSE) -f $(DOCKER_DEV_FILE) down || true
	@$(DOCKER_COMPOSE) -f $(DOCKER_PROD_FILE) down || true
	@echo "$(GREEN)All services stopped!$(NC)"

docker-logs: ## View docker logs
	@echo "$(BOLD)Viewing docker logs...$(NC)"
	@$(DOCKER_COMPOSE) -f $(DOCKER_DEV_FILE) logs -f

docker-build: ## Build all docker images
	@echo "$(BOLD)Building docker images...$(NC)"
	@$(DOCKER_COMPOSE) -f $(DOCKER_DEV_FILE) build
	@echo "$(GREEN)Docker images built!$(NC)"

docker-restart: docker-down ## Restart all docker services
	@echo "$(BOLD)Restarting all services...$(NC)"
	@echo "$(BOLD)Loading environment variables from .env.dev...$(NC)"
	@export $$(grep -v '^#' .env.dev | xargs) && $(DOCKER_COMPOSE) -f $(DOCKER_DEV_FILE) up -d
	@echo "$(BOLD)Restarted all services!$(NC)"

docker-prune: ## Clean up unused Docker resources
	@echo "$(BOLD)Pruning unused Docker resources...$(NC)"
	@docker system prune -f
	@echo "$(GREEN)Docker system pruned!$(NC)"

# ====================
# ETL Commands
# ====================

data-download: ## Download sample e-commerce data
	@echo "$(BOLD)Downloading sample data...$(NC)"
	@mkdir -p $(DATA_DIR)
	@echo "$(YELLOW)Please implement download logic in $(ETL_DIR)/download.py$(NC)"
	@$(PYTHON_VENV) -m $(ETL_DIR).download || echo "$(RED)Download script not implemented yet.$(NC)"

data-load: ## Load data into Supabase
	@echo "$(BOLD)Loading data into Supabase...$(NC)"
	@echo "$(YELLOW)Please implement loading logic in $(ETL_DIR)/loader.py$(NC)"
	@$(PYTHON_VENV) -m $(ETL_DIR).loader || echo "$(RED)Loader script not implemented yet.$(NC)"

db-reset: ## Reset the database (danger: deletes all data)
	@echo "$(BOLD)$(RED)WARNING: This will delete all data in the database.$(NC)"
	@echo "$(BOLD)Are you sure you want to continue? [y/N]$(NC)"
	@read -r response; \
	if [ "$$response" = "y" ] || [ "$$response" = "Y" ]; then \
		echo "$(BOLD)Resetting database...$(NC)"; \
		echo "$(YELLOW)Please implement reset logic in $(ETL_DIR)/reset.py$(NC)"; \
		$(PYTHON_VENV) -m $(ETL_DIR).reset || echo "$(RED)Reset script not implemented yet.$(NC)"; \
	else \
		echo "$(GREEN)Database reset aborted.$(NC)"; \
	fi

# ====================
# Testing Commands
# ====================

test: ## Run all tests
	@echo "$(BOLD)Running all tests...$(NC)"
	@$(PYTHON_VENV) -m pytest -xvs tests/

lint: ## Lint code
	@echo "$(BOLD)Linting code...$(NC)"
	@$(PYTHON_VENV) -m black $(SRC_DIR) tests/
	@$(PYTHON_VENV) -m isort $(SRC_DIR) tests/
	@$(PYTHON_VENV) -m flake8 $(SRC_DIR) tests/
	@echo "$(GREEN)Linting complete!$(NC)"

# ====================
# Documentation Commands
# ====================

docs: ## Generate documentation
	@echo "$(BOLD)Generating documentation...$(NC)"
	@mkdir -p $(DOCS_DIR)
	@$(PYTHON_VENV) -m mkdocs build
	@echo "$(GREEN)Documentation generated in $(DOCS_DIR)!$(NC)"

docs-serve: ## Serve documentation locally
	@echo "$(BOLD)Serving documentation...$(NC)"
	@$(PYTHON_VENV) -m mkdocs serve

# ====================
# Utility Commands
# ====================

clean: dbt-clean ## Clean all artifacts
	@echo "$(BOLD)Cleaning project artifacts...$(NC)"
	@rm -rf __pycache__/
	@rm -rf *.egg-info/
	@rm -rf .pytest_cache/
	@rm -rf .coverage
	@rm -rf build/
	@rm -rf dist/
	@rm -rf $(DOCS_DIR)/site/
	@find . -type d -name __pycache__ -exec rm -rf {} +
	@find . -type d -name "*.egg-info" -exec rm -rf {} +
	@find . -type d -name "*.eggs" -exec rm -rf {} +
	@find . -type f -name "*.pyc" -delete
	@find . -type f -name "*.pyo" -delete
	@find . -type f -name "*.pyd" -delete
	@find . -type f -name ".coverage.*" -delete
	@find . -type f -name "coverage.xml" -delete
	@find . -type f -name ".coverage" -delete
	@echo "$(GREEN)Project cleaned!$(NC)"

create-dbt-structure: ## Create recommended dbt directory structure
	@echo "$(BOLD)Creating recommended dbt structure...$(NC)"
	@mkdir -p $(DBT_DIR)/models/{staging,intermediate,marts}
	@mkdir -p $(DBT_DIR)/seeds
	@mkdir -p $(DBT_DIR)/tests/singular
	@mkdir -p $(DBT_DIR)/macros
	@mkdir -p $(DBT_DIR)/snapshots
	@touch $(DBT_DIR)/models/staging/sources.yml
	@echo "$(GREEN)DBT directory structure created!$(NC)"

create-airflow-dag-dir: ## Create Airflow DAGs directory
	@echo "$(BOLD)Creating Airflow DAGs directory...$(NC)"
	@mkdir -p $(SRC_DIR)/airflow/dags
	@echo "$(GREEN)Airflow DAGs directory created!$(NC)"

create-metabase-dir: ## Create Metabase directory
	@echo "$(BOLD)Creating Metabase directory...$(NC)"
	@mkdir -p $(SRC_DIR)/metabase/{dashboards,questions}
	@echo "$(GREEN)Metabase directory created!$(NC)"