#!/bin/bash

# Deployment script for Lakukan Drive
# This script will deploy the application to VPS

set -e

# Configuration
PROJECT_NAME="lakukan-drive"
DEPLOY_DIR="/opt/$PROJECT_NAME"
BACKUP_DIR="/opt/backups/$PROJECT_NAME"
LOG_DIR="/var/log/$PROJECT_NAME"
DATA_DIR="/opt/data/$PROJECT_NAME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root"
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    error "Docker is not installed"
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    error "Docker Compose is not installed"
fi

log "Starting deployment of $PROJECT_NAME"

# Create necessary directories
log "Creating directories..."
mkdir -p "$DEPLOY_DIR"
mkdir -p "$BACKUP_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "$DATA_DIR"/{data,config,database,logs}
mkdir -p "$DEPLOY_DIR"/nginx/ssl

# Navigate to deployment directory
cd "$DEPLOY_DIR"

# Backup current deployment if exists
if [ -f "docker-compose.prod.yml" ]; then
    log "Backing up current deployment..."
    BACKUP_NAME="backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR/$BACKUP_NAME"
    cp -r . "$BACKUP_DIR/$BACKUP_NAME/" || warning "Failed to backup current deployment"
fi

# Download latest docker-compose files
log "Downloading latest configuration..."
# Note: In a real scenario, you would pull these from your repository
# For now, we assume they're already present

# Set environment variables
export GITHUB_REPOSITORY_OWNER="${GITHUB_REPOSITORY_OWNER:-$(whoami)}"
export COMPOSE_PROJECT_NAME="$PROJECT_NAME"

# Stop existing services
log "Stopping existing services..."
docker-compose -f docker-compose.prod.yml down || true

# Pull latest images
log "Pulling latest Docker images..."
docker-compose -f docker-compose.prod.yml pull

# Start services
log "Starting services..."
docker-compose -f docker-compose.prod.yml up -d

# Wait for services to be healthy
log "Waiting for services to be healthy..."
sleep 30

# Check service health
log "Checking service health..."
if docker-compose -f docker-compose.prod.yml ps | grep -q "Up (healthy)"; then
    log "Services are healthy"
else
    error "Some services are not healthy"
fi

# Clean up old images
log "Cleaning up old Docker images..."
docker image prune -f

# Set up log rotation
log "Setting up log rotation..."
sudo tee /etc/logrotate.d/$PROJECT_NAME > /dev/null <<EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $(whoami) $(whoami)
    postrotate
        docker-compose -f $DEPLOY_DIR/docker-compose.prod.yml restart
    endscript
}
EOF

# Set up monitoring (optional)
log "Setting up basic monitoring..."
cat > "$DEPLOY_DIR/health-check.sh" << 'EOF'
#!/bin/bash

# Simple health check script
COMPOSE_FILE="/opt/lakukan-drive/docker-compose.prod.yml"

if ! docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up (healthy)"; then
    echo "$(date): Services are unhealthy, restarting..."
    docker-compose -f "$COMPOSE_FILE" restart
    sleep 60
    
    if ! docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up (healthy)"; then
        echo "$(date): Services are still unhealthy, sending alert"
        # Add your alert mechanism here (email, Slack, etc.)
    fi
fi
EOF

chmod +x "$DEPLOY_DIR/health-check.sh"

# Add cron job for health check
(crontab -l 2>/dev/null; echo "*/5 * * * * $DEPLOY_DIR/health-check.sh") | crontab -

log "Deployment completed successfully!"
log "Services are running at:"
log "  Frontend: http://localhost"
log "  Backend API: http://localhost/api"
log "  Health check: http://localhost/health"

log "Logs are available at: $LOG_DIR"
log "Configuration files are at: $DEPLOY_DIR"
log "Data is stored at: $DATA_DIR"

log "To view logs: docker-compose -f $DEPLOY_DIR/docker-compose.prod.yml logs -f"
log "To stop services: docker-compose -f $DEPLOY_DIR/docker-compose.prod.yml down"
log "To restart services: docker-compose -f $DEPLOY_DIR/docker-compose.prod.yml restart"