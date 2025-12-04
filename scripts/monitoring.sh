
#!/bin/bash

# Monitoring and Maintenance Script for Lakukan Drive
# This script provides comprehensive monitoring and maintenance functions

set -e

# Configuration
PROJECT_NAME="lakukan-drive"
DEPLOY_DIR="/opt/$PROJECT_NAME"
DATA_DIR="/opt/data/$PROJECT_NAME"
LOG_DIR="/var/log/$PROJECT_NAME"
BACKUP_DIR="/opt/backups/$PROJECT_NAME"

# Alert configuration
ALERT_EMAIL="${ALERT_EMAIL:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"

# Thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=85
SERVICE_RESTART_THRESHOLD=3

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
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Alert functions
send_alert() {
    local message="$1"
    local severity="$2"
    
    # Log the alert
    echo "$(date +'%Y-%m-%d %H:%M:%S') - [$severity] $message" >> "$LOG_DIR/monitoring.log"
    
    # Send email alert
    if [ -n "$ALERT_EMAIL" ]; then
        echo "$message" | mail -s "[$PROJECT_NAME] $severity Alert" "$ALERT_EMAIL"
    fi
    
    # Send Slack alert
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"[$PROJECT_NAME] $severity: $message\"}" \
            "$SLACK_WEBHOOK" 2>/dev/null || true
    fi
    
    # Send Discord alert
    if [ -n "$DISCORD_WEBHOOK" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"content\":\"[$PROJECT_NAME] $severity: $message\"}" \
            "$DISCORD_WEBHOOK" 2>/dev/null || true
    fi
}

# System monitoring functions
check_cpu_usage() {
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    cpu_usage=${cpu_usage%.*}  # Remove decimal part
    
    if [ "$cpu_usage" -gt "$CPU_THRESHOLD" ]; then
        warning "High CPU usage: ${cpu_usage}%"
        send_alert "High CPU usage: ${cpu_usage}%" "WARNING"
        return 1
    fi
    
    info "CPU usage: ${cpu_usage}%"
    return 0
}

check_memory_usage() {
    local mem_usage
    mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    if [ "$mem_usage" -gt "$MEMORY_THRESHOLD" ]; then
        warning "High memory usage: ${mem_usage}%"
        send_alert "High memory usage: ${mem_usage}%" "WARNING"
        return 1
    fi
    
    info "Memory usage: ${mem_usage}%"
    return 0
}

check_disk_usage() {
    local alert_sent=false
    
    # Check main data directory
    if [ -d "$DATA_DIR" ]; then
        local disk_usage
        disk_usage=$(df "$DATA_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
        
        if [ "$disk_usage" -gt "$DISK_THRESHOLD" ]; then
            warning "High disk usage for data: ${disk_usage}%"
            send_alert "High disk usage for data: ${disk_usage}%" "CRITICAL"
            alert_sent=true
        else
            info "Disk usage for data: ${disk_usage}%"
        fi
    fi
    
    # Check backup directory
    if [ -d "$BACKUP_DIR" ]; then
        local backup_usage
        backup_usage=$(df "$BACKUP_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
        
        if [ "$backup_usage" -gt "$DISK_THRESHOLD" ]; then
            warning "High disk usage for backups: ${backup_usage}%"
            send_alert "High disk usage for backups: ${backup_usage}%" "WARNING"
            alert_sent=true
        else
            info "Disk usage for backups: ${backup_usage}%"
        fi
