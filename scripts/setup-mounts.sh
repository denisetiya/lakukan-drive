#!/bin/bash

# Mount Folder Setup Script for Lakukan Drive
# This script will configure mount folders for persistent storage

set -e

# Configuration
PROJECT_NAME="lakukan-drive"
DEPLOY_USER="lakukan-user"
DATA_DIR="/opt/data/$PROJECT_NAME"
MOUNT_DIR="/mnt/$PROJECT_NAME"
BACKUP_DIR="/opt/backups/$PROJECT_NAME"

# External storage configuration
EXTERNAL_STORAGE_DEVICE="${1:-}"  # Pass device path as first argument, e.g., /dev/sdb1
STORAGE_TYPE="${2:-local}"        # Options: local, external, nfs, cloud

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

log "Setting up mount folders for $PROJECT_NAME"

# Create base directories
log "Creating base directories..."
mkdir -p "$DATA_DIR"/{data,config,database,logs,uploads,temp,cache}
mkdir -p "$MOUNT_DIR"
mkdir -p "$BACKUP_DIR"

# Set ownership
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$DATA_DIR"
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$MOUNT_DIR"
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$BACKUP_DIR"

# Setup based on storage type
case "$STORAGE_TYPE" in
    "local")
        log "Setting up local storage..."
        setup_local_storage
        ;;
    "external")
        log "Setting up external storage..."
        setup_external_storage
        ;;
    "nfs")
        log "Setting up NFS storage..."
        setup_nfs_storage
        ;;
    "cloud")
        log "Setting up cloud storage..."
        setup_cloud_storage
        ;;
    *)
        error "Unknown storage type: $STORAGE_TYPE. Use: local, external, nfs, or cloud"
        ;;
esac

setup_local_storage() {
    info "Configuring local storage with optimized settings..."
    
    # Create separate partitions for better performance
    cat > /etc/fstab << EOF
# Lakukan Drive mount points
tmpfs $DATA_DIR/temp tmpfs defaults,size=2G,mode=1777 0 0
tmpfs $DATA_DIR/cache tmpfs defaults,size=1G,mode=1777 0 0
EOF
    
    # Mount tmpfs
    mount -a
    
    # Create directory structure
    mkdir -p "$DATA_DIR"/data/{documents,images,videos,audio,archives,others}
    mkdir -p "$DATA_DIR"/config/{nginx,ssl,app}
    mkdir -p "$DATA_DIR"/database/backups
    mkdir -p "$DATA_DIR"/logs/{nginx,app,system}
    mkdir -p "$DATA_DIR"/uploads/{temp,processing}
    
    # Set proper permissions
    chmod 755 "$DATA_DIR"
    chmod 700 "$DATA_DIR/config"
    chmod 700 "$DATA_DIR/database"
    chmod 755 "$DATA_DIR/logs"
    chmod 755 "$DATA_DIR/uploads"
    
    info "Local storage setup completed"
}

setup_external_storage() {
    if [ -z "$EXTERNAL_STORAGE_DEVICE" ]; then
        error "External storage device not specified. Usage: $0 /dev/sdb1 external"
    fi
    
    info "Setting up external storage on $EXTERNAL_STORAGE_DEVICE..."
    
    # Check if device exists
    if [ ! -b "$EXTERNAL_STORAGE_DEVICE" ]; then
        error "Device $EXTERNAL_STORAGE_DEVICE does not exist"
    fi
    
    # Format device if not formatted
    if ! blkid "$EXTERNAL_STORAGE_DEVICE" &>/dev/null; then
        warning "Device $EXTERNAL_STORAGE_DEVICE is not formatted. Formatting as ext4..."
        mkfs.ext4 -F "$EXTERNAL_STORAGE_DEVICE"
    fi
    
    # Get UUID
    DEVICE_UUID=$(blkid -s UUID -o value "$EXTERNAL_STORAGE_DEVICE")
    
    # Create mount point
    mkdir -p "$MOUNT_DIR"
    
    # Add to fstab
    cat >> /etc/fstab << EOF
# Lakukan Drive external storage
UUID=$DEVICE_UUID $MOUNT_DIR ext4 defaults,noatime,auto,rw,exec,user 0 0
EOF
    
    # Mount the device
    mount "$MOUNT_DIR"
    
    # Create directory structure on external storage
    mkdir -p "$MOUNT_DIR"/{data,config,database,logs,uploads,backups}
    
    # Create symlinks from data dir to external storage
    ln -sf "$MOUNT_DIR/data" "$DATA_DIR/data"
    ln -sf "$MOUNT_DIR/config" "$DATA_DIR/config"
    ln -sf "$MOUNT_DIR/database" "$DATA_DIR/database"
    ln -sf "$MOUNT_DIR/logs" "$DATA_DIR/logs"
    ln -sf "$MOUNT_DIR/uploads" "$DATA_DIR/uploads"
    ln -sf "$MOUNT_DIR/backups" "$BACKUP_DIR"
    
    # Set ownership
    chown -R "$DEPLOY_USER:$DEPLOY_USER" "$MOUNT_DIR"
    
    info "External storage setup completed"
}

setup_nfs_storage() {
    NFS_SERVER="${3:-}"
    NFS_PATH="${4:-}"
    
    if [ -z "$NFS_SERVER" ] || [ -z "$NFS_PATH" ]; then
        error "NFS server and path not specified. Usage: $0 '' nfs <server> <path>"
    fi
    
    info "Setting up NFS storage from $NFS_SERVER:$NFS_PATH..."
    
    # Install NFS client
    apt-get update && apt-get install -y nfs-common
    
    # Create mount point
    mkdir -p "$MOUNT_DIR"
    
    # Add to fstab
    cat >> /etc/fstab << EOF
# Lakukan Drive NFS storage
$NFS_SERVER:$NFS_PATH $MOUNT_DIR nfs defaults,rw,auto,_netdev 0 0
EOF
    
    # Mount NFS share
    mount "$MOUNT_DIR"
    
    # Create directory structure
    mkdir -p "$MOUNT_DIR"/{data,config,database,logs,uploads,backups}
    
    # Create symlinks
    ln -sf "$MOUNT_DIR/data" "$DATA_DIR/data"
    ln -sf "$MOUNT_DIR/config" "$DATA_DIR/config"
    ln -sf "$MOUNT_DIR/database" "$DATA_DIR/database"
    ln -sf "$MOUNT_DIR/logs" "$DATA_DIR/logs"
    ln -sf "$MOUNT_DIR/uploads" "$DATA_DIR/uploads"
    ln -sf "$MOUNT_DIR/backups" "$BACKUP_DIR"
    
    # Set ownership
    chown -R "$DEPLOY_USER:$DEPLOY_USER" "$MOUNT_DIR"
    
    info "NFS storage setup completed"
}

setup_cloud_storage() {
    info "Setting up cloud storage using rclone..."
    
    # Install rclone
    curl -s https://rclone.org/install.sh | bash
    
    # Create rclone configuration directory
    mkdir -p "/home/$DEPLOY_USER/.config/rclone"
    chown -R "$DEPLOY_USER:$DEPLOY_USER" "/home/$DEPLOY_USER/.config"
    
    # Create rclone mount script
    cat > /usr/local/bin/$PROJECT_NAME-cloud-mount.sh << 'EOF'
#!/bin/bash

PROJECT_NAME="lakukan-drive"
DEPLOY_USER="lakukan-user"
MOUNT_DIR="/mnt/$PROJECT_NAME"

# Check if rclone is configured
if [ ! -f "/home/$DEPLOY_USER/.config/rclone/rclone.conf" ]; then
    echo "rclone not configured. Please run: sudo -u $DEPLOY_USER rclone config"
    exit 1
fi

# Create mount point
mkdir -p "$MOUNT_DIR"

# Mount cloud storage
rclone mount --allow-other --allow-non-empty --daemon --dir-cache-time 5m --vfs-cache-mode writes cloud: "$MOUNT_DIR"

echo "Cloud storage mounted at $MOUNT_DIR"
EOF

    chmod +x /usr/local/bin/$PROJECT_NAME-cloud-mount.sh
    
    # Create systemd service for auto-mount
    cat > /etc/systemd/system/$PROJECT_NAME-cloud-mount.service << EOF
[Unit]
Description=Lakukan Drive Cloud Storage Mount
After=network-online.target

[Service]
Type=simple
User=$DEPLOY_USER
ExecStart=/usr/local/bin/$PROJECT_NAME-cloud-mount.sh
ExecStop=/bin/fusermount -u $MOUNT_DIR
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable $PROJECT_NAME-cloud-mount.service
    
    warning "Cloud storage setup requires manual configuration:"
    warning "1. Run: sudo -u $DEPLOY_USER rclone config"
    warning "2. Configure your cloud storage provider"
    warning "3. Start the service: systemctl start $PROJECT_NAME-cloud-mount"
}

# Setup monitoring for disk usage
log "Setting up disk usage monitoring..."
cat > /usr/local/bin/$PROJECT_NAME-disk-monitor.sh << EOF
#!/bin/bash

PROJECT_NAME="lakukan-drive"
DATA_DIR="/opt/data/$PROJECT_NAME"
MOUNT_DIR="/mnt/$PROJECT_NAME"
LOG_FILE="/var/log/$PROJECT_NAME/disk-monitor.log"

# Function to log messages
log_message() {
    echo "\$(date +'%Y-%m-%d %H:%M:%S') - \$1" >> "\$LOG_FILE"
}

# Check mount points
if [ -d "\$MOUNT_DIR" ]; then
    if ! mountpoint -q "\$MOUNT_DIR"; then
        log_message "WARNING: Mount point \$MOUNT_DIR is not mounted"
        # Try to remount
        mount "\$MOUNT_DIR" 2>/dev/null || log_message "ERROR: Failed to mount \$MOUNT_DIR"
    fi
fi

# Check disk usage
for dir in "\$DATA_DIR" "\$MOUNT_DIR"; do
    if [ -d "\$dir" ]; then
        DISK_USAGE=\$(df "\$dir" | awk 'NR==2 {print \$5}' | sed 's/%//')
        if [ "\$DISK_USAGE" -gt 85 ]; then
            log_message "CRITICAL: Disk usage for \$dir is \${DISK_USAGE}%"
        elif [ "\$DISK_USAGE" -gt 75 ]; then
            log_message "WARNING: Disk usage for \$dir is \${DISK_USAGE}%"
        fi
    fi
done
EOF

chmod +x /usr/local/bin/$PROJECT_NAME-disk-monitor.sh

# Add to cron (every 5 minutes)
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/$PROJECT_NAME-disk-monitor.sh") | crontab -

# Create cleanup script
log "Creating cleanup script..."
cat > /usr/local/bin/$PROJECT_NAME-cleanup.sh << EOF
#!/bin/bash

PROJECT_NAME="lakukan-drive"
DATA_DIR="/opt/data/$PROJECT_NAME"

# Clean temporary files
find "\$DATA_DIR/temp" -type f -mtime +1 -delete 2>/dev/null || true
find "\$DATA_DIR/cache" -type f -mtime +7 -delete 2>/dev/null || true
find "\$DATA_DIR/logs" -name "*.log" -mtime +30 -delete 2>/dev/null || true

# Clean old database backups
find "\$DATA_DIR/database/backups" -name "*.db.backup" -mtime +7 -delete 2>/dev/null || true

# Clean upload temp files
find "\$DATA_DIR/uploads/temp" -type f -mtime +1 -delete 2>/dev/null || true

echo "Cleanup completed"
EOF

chmod +x /usr/local/bin/$PROJECT_NAME-cleanup.sh

# Add cleanup to cron (daily at 3 AM)
(crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/$PROJECT_NAME-cleanup.sh") | crontab -

log "Mount folder setup completed successfully!"
log ""
log "Mount points configured:"
log "  Data directory: $DATA_DIR"
log "  Mount directory: $MOUNT_DIR"
log "  Backup directory: $BACKUP_DIR"
log ""
log "Monitoring and maintenance:"
log "  Disk monitor: /usr/local/bin/$PROJECT_NAME-disk-monitor.sh"
log "  Cleanup script: /usr/local/bin/$PROJECT_NAME-cleanup.sh"
log ""
log "To check mount status: df -h | grep $PROJECT_NAME"
log "To check disk usage: du -sh $DATA_DIR/*"