# Build Docker Image secara Local

## Panduan Lengkap Build Docker Image untuk Lakukan Drive

## Prerequisites

Pastikan Docker dan Docker Compose sudah terinstall:

```bash
# Cek Docker
docker --version

# Cek Docker Compose
docker-compose --version
```

## Build Frontend Docker Image

### Method 1: Menggunakan Makefile (Recommended)

```bash
# Build frontend image
make build-frontend

# Atau build semua Docker images
make build-docker
```

### Method 2: Manual Build

```bash
# Build frontend image
docker build -t lakukan-drive-frontend ./frontend

# Build dengan tag khusus
docker build -t your-username/lakukan-drive-frontend:latest ./frontend
docker build -t your-username/lakukan-drive-frontend:v1.0.0 ./frontend
```

## Build Backend Docker Image

### Method 1: Menggunakan Makefile (Recommended)

```bash
# Build backend image
make build-backend

# Atau build semua Docker images
make build-docker
```

### Method 2: Manual Build

```bash
# Build backend image
docker build -t lakukan-drive-backend .

# Build dengan tag khusus
docker build -t your-username/lakukan-drive-backend:latest .
docker build -t your-username/lakukan-drive-backend:v1.0.0 .
```

## Build dengan Multi-Stage Build Optimization

### Frontend dengan Build Cache

```bash
# Build dengan cache optimization
docker build \
  --target builder \
  --cache-from lakukan-drive-frontend:cache \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  -t lakukan-drive-frontend:cache \
  ./frontend

# Build final image
docker build \
  --cache-from lakukan-drive-frontend:cache \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  -t lakukan-drive-frontend:latest \
  ./frontend
```

### Backend dengan Build Args

```bash
# Build dengan custom build args
docker build \
  --build-arg VERSION=1.0.0 \
  --build-arg COMMIT_SHA=$(git rev-parse --short HEAD) \
  -t lakukan-drive-backend:latest \
  .
```

## Build untuk Platform Berbeda

```bash
# Build untuk multiple platforms
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t your-username/lakukan-drive-frontend:latest \
  ./frontend

# Build untuk ARM64 (untuk Raspberry Pi atau ARM server)
docker buildx build \
  --platform linux/arm64 \
  -t lakukan-drive-frontend:arm64 \
  ./frontend
```

## Run Images secara Local

### Method 1: Menggunakan Docker Compose

```bash
# Development environment
make dev

# Production environment
make prod

# Atau manual
docker-compose -f docker-compose.dev.yml up -d
docker-compose -f docker-compose.prod.yml up -d
```

### Method 2: Manual Docker Run

```bash
# Run frontend
docker run -d \
  --name lakukan-drive-frontend \
  -p 3000:80 \
  lakukan-drive-frontend:latest

# Run backend
docker run -d \
  --name lakukan-drive-backend \
  -p 8080:80 \
  -v $(pwd)/data:/srv \
  -v $(pwd)/config:/config \
  -v $(pwd)/database:/database \
  lakukan-drive-backend:latest
```

## Development dengan Live Reload

### Frontend Development

```bash
# Build development image dengan volume mounting
docker build -t lakukan-drive-frontend:dev ./frontend

# Run dengan volume mounting untuk live reload
docker run -it --rm \
  -p 3000:3000 \
  -v $(pwd)/frontend:/app \
  -v /app/node_modules \
  lakukan-drive-frontend:dev \
  pnpm run dev
```

### Backend Development

```bash
# Build development image
docker build -t lakukan-drive-backend:dev .

# Run dengan volume mounting
docker run -it --rm \
  -p 8080:8080 \
  -v $(pwd)/backend:/app \
  lakukan-drive-backend:dev \
  go run main.go
```

## Debug Build Issues

### Check Build Process

```bash
# Build dengan verbose output
docker build --verbose -t lakukan-drive-frontend ./frontend

# Build step-by-step
docker build --no-cache -t lakukan-drive-frontend ./frontend

# Inspect intermediate layers
docker history lakukan-drive-frontend:latest
```

### Debug Frontend Build

```bash
# Run interactive build container
docker run -it --rm \
  -v $(pwd)/frontend:/app \
  -w /app \
  node:24-alpine \
  sh

# Inside container:
# npm install -g pnpm
# pnpm install
# pnpm run build
# ls -la dist/
```

### Debug Backend Build

```bash
# Run interactive build container
docker run -it --rm \
  -v $(pwd):/app \
  -w /app \
  golang:1.25-alpine \
  sh

# Inside container:
# go mod download
# go build -o lakukandrive ./backend
# ls -la lakukandrive
```

## Optimize Image Size

### Frontend Optimization

```bash
# Use multi-stage build dengan Alpine base
docker build \
  --target production \
  -t lakukan-drive-frontend:alpine \
  ./frontend

# Use distroless untuk minimal size
docker build \
  -f frontend/Dockerfile.distroless \
  -t lakukan-drive-frontend:distroless \
  ./frontend
```

### Backend Optimization

```bash
# Build dengan static binary
docker build \
  --build-arg CGO_ENABLED=0 \
  --build-arg GOOS=linux \
  -t lakukan-drive-backend:static \
  .

# Use scratch base image
docker build \
  -f Dockerfile.scratch \
  -t lakukan-drive-backend:scratch \
  .
```

## Tag dan Push ke Registry

### Tag Images

```bash
# Tag untuk GitHub Container Registry
docker tag lakukan-drive-frontend:latest ghcr.io/username/lakukan-drive-frontend:latest
docker tag lakukan-drive-backend:latest ghcr.io/username/lakukan-drive-backend:latest

# Tag dengan version
docker tag lakukan-drive-frontend:latest ghcr.io/username/lakukan-drive-frontend:v1.0.0
docker tag lakukan-drive-backend:latest ghcr.io/username/lakukan-drive-backend:v1.0.0
```

### Push ke Registry

```bash
# Login ke GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u username --password-stdin

# Push images
docker push ghcr.io/username/lakukan-drive-frontend:latest
docker push ghcr.io/username/lakukan-drive-backend:latest
docker push ghcr.io/username/lakukan-drive-frontend:v1.0.0
docker push ghcr.io/username/lakukan-drive-backend:v1.0.0
```

## Cleanup

### Remove Images

```bash
# Remove specific images
docker rmi lakukan-drive-frontend:latest
docker rmi lakukan-drive-backend:latest

# Remove all Lakukan Drive images
docker rmi $(docker images "lakukan-drive-*" -q)

# Remove all unused images
docker image prune -a
```

### Remove Containers

```bash
# Stop dan remove containers
docker stop lakukan-drive-frontend lakukan-drive-backend
docker rm lakukan-drive-frontend lakukan-drive-backend

# Remove all stopped containers
docker container prune
```

## Troubleshooting Common Issues

### Port Conflicts

```bash
# Cek port yang digunakan
netstat -tulpn | grep :3000
netstat -tulpn | grep :8080

# Kill process yang menggunakan port
sudo kill -9 $(sudo lsof -t -i:3000)
```

### Permission Issues

```bash
# Fix Docker permissions
sudo usermod -aG docker $USER
newgrp docker

# Fix volume permissions
sudo chown -R $USER:$USER ./data ./config ./database
```

### Memory Issues

```bash
# Increase Docker memory limit
# Docker Desktop: Settings > Resources > Memory

# Check container resource usage
docker stats
```

## Quick Start Commands

```bash
# 1. Build semua images
make build-docker

# 2. Start development environment
make dev

# 3. Cek status
make status

# 4. View logs
make dev-logs

# 5. Stop environment
make dev-stop

# 6. Cleanup
make clean
```

## Environment Variables

```bash
# Copy environment template
cp .env.example .env

# Edit environment variables
nano .env

# Build dengan environment variables
docker build --build-arg NODE_ENV=production -t lakukan-drive-frontend ./frontend
```

## Advanced Build Options

### Build dengan BuildKit

```bash
# Enable BuildKit
export DOCKER_BUILDKIT=1

# Build dengan cache mount
docker build \
  --cache-from type=local,src=/tmp/.buildx-cache \
  --cache-to type=local,dest=/tmp/.buildx-cache \
  -t lakukan-drive-frontend ./frontend
```

### Build dengan Custom Dockerfile

```bash
# Build dengan Dockerfile khusus
docker build -f Dockerfile.custom -t lakukan-drive-frontend ./frontend

# Build dengan build context berbeda
docker build -f ../Dockerfile -t lakukan-drive-frontend ./frontend
```

Dengan panduan ini, Anda bisa build Docker images secara local untuk development, testing, atau sebelum push ke production.