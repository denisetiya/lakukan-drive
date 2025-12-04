#!/bin/bash

# VPS Setup Script for Lakukan Drive
# This script will set up the VPS with Docker and necessary configurations

set -e

# Configuration
PROJECT_NAME="lakukan-drive"
DEPLOY_USER="lakukan-user"
DEPLOY_DIR="/opt/$PROJECT_NAME"
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
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

log "Starting VPS setup for $PROJECT_NAME"

# Update system
log "Updating system packages..."
apt update && apt upgrade -y

# Install required packages
log "Installing required packages..."
apt install -y \
    curl \
    wget \
    git \
    htop \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    ufw \
    certbot \
    python3-certbot-nginx

# Create deploy user
log "Creating deploy user..."
if ! id "$DEPLOY_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$DEPLOY_USER"
    usermod -aG sudo "$DEPLOY_USER"
    
    # Setup sudo without password for docker commands
    echo "$DEPLOY_USER ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/bin/docker-compose, /usr/bin/systemctl restart docker, /usr/bin/systemctl reload nginx" >> /etc/sudoers.d/lakukan-drive
fi

# Install Docker
log "Installing Docker..."
if ! command -v docker &> /dev/null; then
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Set up the stable repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add deploy user to docker group
    usermod -aG docker "$DEPLOY_USER"
else
    log "Docker is already installed"
fi

# Install Docker Compose
log "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    # Download Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    log "Docker Compose is already installed"
fi

# Setup firewall
log "Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Create directories
log "Creating directories..."
mkdir -p "$DEPLOY_DIR"
mkdir -p "$DATA_DIR"/{data,config,database,logs}
mkdir -p /opt/backups/"$PROJECT_NAME"
mkdir -p /var/log/"$PROJECT_NAME"

# Set ownership
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$DEPLOY_DIR"
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$DATA_DIR"
chown -R "$DEPLOY_USER:$DEPLOY_USER" /opt/backups/"$PROJECT_NAME"
chown -R "$DEPLOY_USER:$DEPLOY_USER" /var/log/"$PROJECT_NAME"

# Setup swap space (if needed)
if [ $(free -m | awk '/^Swap:/ {print $2}') -lt 2048 ]; then
    log "Setting up swap space..."
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo 'vm.swappiness=10' >> /etc/sysctl.conf
fi

# Optimize system for Docker
log "Optimizing system for Docker..."
cat >> /etc/sysctl.conf << EOF

# Docker optimization
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.core.netdev_max_backlog = 5000
vm.max_map_count = 262144
EOF

sysctl -p

# Setup log rotation
log "Setting up log rotation..."
cat > /etc/logrotate.d/$PROJECT_NAME << EOF
/var/log/$PROJECT_NAME/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $DEPLOY_USER $DEPLOY_USER
    postrotate
        docker-compose -f $DEPLOY_DIR/docker-compose.prod.yml restart
    endscript
}
EOF

# Setup monitoring script
log "Setting up monitoring script..."
cat > /usr/local/bin/$PROJECT_NAME-monitor.sh << 'EOF'
#!/bin/bash

PROJECT_NAME="lakukan-drive"
DEPLOY_DIR="/opt/$PROJECT_NAME"
LOG_FILE="/var/log/$PROJECT_NAME/monitor.log"

# Function to log messages
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Check Docker service
if ! systemctl is-active --quiet docker; then
    log_message "Docker service is not running, starting it..."
    systemctl start docker
fi

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    log_message "WARNING: Disk usage is ${DISK_USAGE}%"
fi

# Check memory usage
MEM_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
if [ "$MEM_USAGE" -gt 80 ]; then
    log_message "WARNING: Memory usage is ${MEM_USAGE}%"
fi

# Check if containers are running
if [ -f "$DEPLOY_DIR/docker-compose.prod.yml" ]; then
    cd "$DEPLOY_DIR"
    if ! docker-compose -f docker-compose.prod.yml ps | grep -q "Up"; then
        log_message "ERROR: Services are not running, restarting..."
        docker-compose -f docker-compose.prod.yml restart
    fi
fi
EOF

chmod +x /usr/local/bin/$PROJECT_NAME-monitor.sh

# Add monitoring to cron
(crontab -l 2>/dev/null; echo "*/10 * * * * /usr/local/bin/$PROJECT_NAME-monitor.sh") | crontab -

# Setup backup script
log "Setting up backup script..."
cat > /usr/local/bin/$PROJECT_NAME-backup.sh << EOF
#!/bin/bash

PROJECT_NAME="lakukan-drive"
DEPLOY_DIR="/opt/$PROJECT_NAME"
DATA_DIR="/opt/data/$PROJECT_NAME"
BACKUP_DIR="/opt/backups/$PROJECT_NAME"
BACKUP_NAME="backup-\$(date +%Y%m%d-%H%M%S)"
RETENTION_DAYS=7

# Create backup directory
mkdir -p "\$BACKUP_DIR/\$BACKUP_NAME"

# Backup data
if [ -d "\$DATA_DIR" ]; then
    tar -czf "\$BACKUP_DIR/\$BACKUP_NAME/data.tar.gz" -C "\$DATA_DIR" .
fi

# Backup configuration
if [ -f "\$DEPLOY_DIR/docker-compose.prod.yml" ]; then
    cp "\$DEPLOY_DIR/docker-compose.prod.yml" "\$BACKUP_DIR/\$BACKUP_NAME/"
fi

# Remove old backups
find "\$BACKUP_DIR" -type d -name "backup-*" -mtime +\$RETENTION_DAYS -exec rm -rf {} +

echo "Backup completed: \$BACKUP_NAME"
EOF

chmod +x /usr/local/bin/$PROJECT_NAME-backup.sh

# Add backup to cron (daily at 2 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/$PROJECT_NAME-backup.sh") | crontab -

# Create systemd service for auto-start
log "Creating systemd service..."
cat > /etc/systemd/system/$PROJECT_NAME.service << EOF
[Unit]
Description=Lakukan Drive
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$DEPLOY_DIR
ExecStart=/usr/local/bin/docker-compose -f docker-compose.prod.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.prod.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl enable $PROJECT_NAME.service

log "VPS setup completed successfully!"
log ""
log "Next steps:"
log "1. Switch to deploy user: su - $DEPLOY_USER"
log "2. Run the deployment script: bash /opt/$PROJECT_NAME/scripts/deploy.sh"
log "3. Configure your domain and SSL certificate"
log ""
log "Important directories:"
log "  Application: $DEPLOY_DIR"
log "  Data: $DATA_DIR"
log "  Backups: /opt/backups/$PROJECT_NAME"
log "  Logs: /var/log/$PROJECT_NAME"
log ""
log "Monitoring and maintenance:"
log "  Monitor script: /usr/local/bin/$PROJECT_NAME-monitor.sh"
log "  Backup script: /usr/local/bin/$PROJECT_NAME-backup.sh"
log "  Service: systemctl $PROJECT_NAME.service"