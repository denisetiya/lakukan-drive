# Makefile for Lakukan Drive
# This file provides convenient commands for development and deployment

.PHONY: help build dev prod deploy clean test lint logs status docker-build docker-build-local

# Default target
help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Development commands
dev: ## Start development environment
	@echo "Starting development environment..."
	docker-compose -f docker-compose.dev.yml up -d
	@echo "Services started:"
	@echo "  Frontend: http://localhost:3000"
	@echo "  Backend:  http://localhost:8080"

dev-logs: ## Show development logs
	docker-compose -f docker-compose.dev.yml logs -f

dev-stop: ## Stop development environment
	docker-compose -f docker-compose.dev.yml down

dev-restart: ## Restart development environment
	docker-compose -f docker-compose.dev.yml restart

# Production commands
prod: ## Start production environment
	@echo "Starting production environment..."
	docker-compose -f docker-compose.prod.yml up -d
	@echo "Services started:"
	@echo "  Frontend: http://localhost"
	@echo "  Backend:  http://localhost/api"

prod-logs: ## Show production logs
	docker-compose -f docker-compose.prod.yml logs -f

prod-stop: ## Stop production environment
	docker-compose -f docker-compose.prod.yml down

prod-restart: ## Restart production environment
	docker-compose -f docker-compose.prod.yml restart

# Build commands
build: ## Build frontend and backend
	@echo "Building frontend..."
	cd frontend && pnpm install && pnpm run build
	@echo "Building backend..."
	task build:backend

build-frontend: ## Build frontend only
	cd frontend && pnpm install && pnpm run build

build-backend: ## Build backend only
	task build:backend

build-docker: ## Build Docker images
	@echo "Building frontend Docker image..."
	docker build -t lakukan-drive-frontend ./frontend
	@echo "Building backend Docker image..."
	docker build -t lakukan-drive-backend .

docker-build: ## Build Docker images with custom tags
	@read -p "Enter registry (default: ghcr.io/username): " registry; \
	read -p "Enter version (default: latest): " version; \
	read -p "Enter platform (default: linux/amd64): " platform; \
	registry=$${registry:-ghcr.io/username}; \
	version=$${version:-latest}; \
	platform=$${platform:-linux/amd64}; \
	echo "Building frontend image: $$registry/lakukan-drive-frontend:$$version"; \
	docker build --platform $$platform -t $$registry/lakukan-drive-frontend:$$version ./frontend; \
	echo "Building backend image: $$registry/lakukan-drive-backend:$$version"; \
	docker build --platform $$platform -t $$registry/lakukan-drive-backend:$$version .; \
	echo "Build completed successfully!"

docker-build-local: ## Build Docker images locally for development
	@echo "Building local Docker images..."
	@echo "Building frontend image..."
	docker build -t lakukan-drive-frontend:local ./frontend
	@echo "Building backend image..."
	docker build -t lakukan-drive-backend:local .
	@echo "Local build completed!"
	@echo "Run with: docker-compose -f docker-compose.local.yml up -d"

docker-build-cache: ## Build Docker images with cache optimization
	@echo "Building Docker images with cache..."
	docker build \
		--cache-from lakukan-drive-frontend:cache \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		-t lakukan-drive-frontend:cache \
		./frontend
	docker build \
		--cache-from lakukan-drive-frontend:cache \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		-t lakukan-drive-frontend:latest \
		./frontend
	@echo "Cache build completed!"

docker-push: ## Push Docker images to registry
	@read -p "Enter registry (default: ghcr.io/username): " registry; \
	read -p "Enter version (default: latest): " version; \
	registry=$${registry:-ghcr.io/username}; \
	version=$${version:-latest}; \
	echo "Pushing images to $$registry..."; \
	docker push $$registry/lakukan-drive-frontend:$$version; \
	docker push $$registry/lakukan-drive-backend:$$version; \
	echo "Push completed!"

docker-tag: ## Tag Docker images with custom tags
	@read -p "Enter source tag (default: latest): " source; \
	read -p "Enter target tag: " target; \
	source=$${source:-latest}; \
	echo "Tagging lakukan-drive-frontend:$$source as lakukan-drive-frontend:$$target"; \
	docker tag lakukan-drive-frontend:$$source lakukan-drive-frontend:$$target; \
	echo "Tagging lakukan-drive-backend:$$source as lakukan-drive-backend:$$target"; \
	docker tag lakukan-drive-backend:$$source lakukan-drive-backend:$$target; \
	echo "Tagging completed!"

docker-run-local: ## Run local Docker images
	@echo "Running local Docker images..."
	docker-compose -f docker-compose.local.yml up -d
	@echo "Services started:"
	@echo "  Frontend: http://localhost:3000"
	@echo "  Backend:  http://localhost:8080"

# Test commands
test: ## Run all tests
	@echo "Running backend tests..."
	go test ./...
	@echo "Running frontend tests..."
	cd frontend && pnpm test

test-backend: ## Run backend tests only
	go test ./...

test-frontend: ## Run frontend tests only
	cd frontend && pnpm test

# Lint commands
lint: ## Run all linters
	@echo "Linting backend..."
	golangci-lint run
	@echo "Linting frontend..."
	cd frontend && pnpm run lint

lint-backend: ## Lint backend only
	golangci-lint run

lint-frontend: ## Lint frontend only
	cd frontend && pnpm run lint

lint-fix: ## Fix linting issues
	@echo "Fixing backend linting issues..."
	golangci-lint run --fix
	@echo "Fixing frontend linting issues..."
	cd frontend && pnpm run lint:fix

# Deployment commands
deploy: ## Deploy to production (requires setup)
	@echo "Deploying to production..."
	bash scripts/deploy.sh

setup-vps: ## Setup VPS (run as root)
	@echo "Setting up VPS..."
	sudo bash scripts/setup-vps.sh

setup-mounts: ## Setup mount folders (run as root)
	@echo "Setting up mount folders..."
	sudo bash scripts/setup-mounts.sh

setup-external: ## Setup external storage (run as root)
	@echo "Setting up external storage..."
	@read -p "Enter device path (e.g., /dev/sdb1): " device; \
	sudo bash scripts/setup-mounts.sh $$device external

setup-nfs: ## Setup NFS storage (run as root)
	@echo "Setting up NFS storage..."
	@read -p "Enter NFS server IP: " server; \
	read -p "Enter NFS path: " path; \
	sudo bash scripts/setup-mounts.sh "" nfs $$server $$path

# Status commands
status: ## Show service status
	@echo "Development services:"
	@docker-compose -f docker-compose.dev.yml ps 2>/dev/null || echo "Not running"
	@echo ""
	@echo "Production services:"
	@docker-compose -f docker-compose.prod.yml ps 2>/dev/null || echo "Not running"

logs: ## Show all logs
	@echo "Development logs:"
	@docker-compose -f docker-compose.dev.yml logs --tail=50 2>/dev/null || echo "No logs"
	@echo ""
	@echo "Production logs:"
	@docker-compose -f docker-compose.prod.yml logs --tail=50 2>/dev/null || echo "No logs"

# Utility commands
clean: ## Clean up Docker resources
	@echo "Cleaning up Docker resources..."
	docker system prune -f
	docker volume prune -f
	docker network prune -f

clean-all: ## Clean up all Docker resources (including images)
	@echo "Cleaning up all Docker resources..."
	docker system prune -a -f
	docker volume prune -f
	docker network prune -f

backup: ## Create backup
	@echo "Creating backup..."
	/usr/local/bin/lakukan-drive-backup.sh || echo "Backup script not found"

monitor: ## Show system monitoring
	@echo "System monitoring:"
	@echo "Disk usage:"
	@df -h | grep -E "(Filesystem|/dev/)"
	@echo ""
	@echo "Memory usage:"
	@free -h
	@echo ""
	@echo "Docker containers:"
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

update: ## Update system and dependencies
	@echo "Updating system packages..."
	sudo apt update && sudo apt upgrade -y
	@echo "Updating Docker images..."
	docker-compose -f docker-compose.prod.yml pull
	@echo "Restarting services..."
	docker-compose -f docker-compose.prod.yml up -d

# SSL commands
ssl-renew: ## Renew SSL certificate
	@echo "Renewing SSL certificate..."
	sudo certbot renew

ssl-setup: ## Setup SSL certificate
	@read -p "Enter domain name: " domain; \
	sudo certbot --nginx -d $$domain

# Database commands
db-backup: ## Backup database
	@echo "Backing up database..."
	mkdir -p ./database/backups
	cp ./database/lakukandrive.db ./database/backups/lakukandrive_$(shell date +%Y%m%d_%H%M%S).db.backup

db-restore: ## Restore database
	@echo "Available backups:"
	@ls -la ./database/backups/
	@read -p "Enter backup filename: " backup; \
	cp ./database/backups/$$backup ./database/lakukandrive.db

# Development utilities
install-deps: ## Install all dependencies
	@echo "Installing frontend dependencies..."
	cd frontend && pnpm install
	@echo "Installing backend dependencies..."
	go mod download
	go mod tidy

watch-frontend: ## Watch frontend for changes
	cd frontend && pnpm run dev

watch-backend: ## Watch backend for changes
	go run ./backend/main.go

# Quick start commands
quick-dev: ## Quick start development environment
	make install-deps
	make build
	make dev

quick-prod: ## Quick start production environment
	make build-docker
	make prod

# Security commands
security-scan: ## Run security scan
	@echo "Running security scan..."
	gosec ./...
	npm audit --audit-level moderate

security-update: ## Update security packages
	@echo "Updating security packages..."
	sudo apt update && sudo apt upgrade -y
	cd frontend && pnpm audit fix
	go get -u ./...
	go mod tidy