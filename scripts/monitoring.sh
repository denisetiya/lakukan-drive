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
    fi
    
    if [ "$alert_sent" = true ]; then
        return 1
    fi
    
    return 0
}

check_service_health() {
    local services_down=false
    
    if [ -f "$DEPLOY_DIR/docker-compose.prod.yml" ]; then
        cd "$DEPLOY_DIR"
        
        # Check if services are running
        if ! docker-compose -f docker-compose.prod.yml ps | grep -q "Up"; then
            error "No services are running"
            send_alert "No services are running" "CRITICAL"
            services_down=true
        else
            # Check individual service health
            local unhealthy_services
            unhealthy_services=$(docker-compose -f docker-compose.prod.yml ps | grep -v "Up (healthy)" | grep "Up" | wc -l)
            
            if [ "$unhealthy_services" -gt 0 ]; then
                warning "$unhealthy_services services are unhealthy"
                send_alert "$unhealthy_services services are unhealthy" "WARNING"
                services_down=true
            else
                info "All services are healthy"
            fi
        fi
    else
        warning "Docker Compose file not found"
        services_down=true
    fi
    
    if [ "$services_down" = true ]; then
        return 1
    fi
    
    return 0
}

check_mount_points() {
    local mount_issues=false
    
    # Check if mount points are mounted
    if mountpoint -q "/mnt/$PROJECT_NAME" 2>/dev/null; then
        info "External mount point is mounted"
    else
        warning "External mount point is not mounted"
        mount_issues=true
    fi
    
    # Check if we can write to data directory
    if [ -d "$DATA_DIR" ]; then
        if ! touch "$DATA_DIR/.test_write" 2>/dev/null; then
            error "Cannot write to data directory"
            send_alert "Cannot write to data directory" "CRITICAL"
            mount_issues=true
        else
            rm -f "$DATA_DIR/.test_write"
            info "Data directory is writable"
        fi
    fi
    
    if [ "$mount_issues" = true ]; then
        return 1
    fi
    
    return 0
}

check_network_connectivity() {
    local connectivity_issues=false
    
    # Check DNS resolution
    if ! nslookup google.com >/dev/null 2>&1; then
        warning "DNS resolution is not working"
        connectivity_issues=true
    fi
    
    # Check external connectivity
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        warning "External connectivity is not working"
        connectivity_issues=true
    fi
    
    # Check if ports are accessible
    if ! nc -z localhost 80 >/dev/null 2>&1; then
        warning "Port 80 is not accessible"
        connectivity_issues=true
    fi
    
    if [ "$connectivity_issues" = true ]; then
        send_alert "Network connectivity issues detected" "WARNING"
        return 1
    fi
    
    info "Network connectivity is working"
    return 0
}

# Maintenance functions
cleanup_temp_files() {
    info "Cleaning up temporary files..."
    
    # Clean temp directories
    find "$DATA_DIR/temp" -type f -mtime +1 -delete 2>/dev/null || true
    find "$DATA_DIR/cache" -type f -mtime +7 -delete 2>/dev/null || true
    find "$DATA_DIR/uploads/temp" -type f -mtime +1 -delete 2>/dev/null || true
    
    # Clean old logs
    find "$LOG_DIR" -name "*.log" -mtime +30 -delete 2>/dev/null || true
    
    # Clean Docker
    docker system prune -f >/dev/null 2>&1 || true
    
    info "Temporary files cleanup completed"
}

optimize_database() {
    if [ -f "$DATA_DIR/database/lakukandrive.db" ]; then
        info "Optimizing database..."
        
        # Create backup before optimization
        cp "$DATA_DIR/database/lakukandrive.db" "$DATA_DIR/database/backups/lakukandrive_$(date +%Y%m%d_%H%M%S).db.backup"
        
        # Optimize SQLite database
        sqlite3 "$DATA_DIR/database/lakukandrive.db" "VACUUM;" 2>/dev/null || true
        
        info "Database optimization completed"
    fi
}

rotate_logs() {
    info "Rotating logs..."
    
    # Rotate application logs
    for log_file in "$LOG_DIR"/*.log; do
        if [ -f "$log_file" ] && [ $(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file") -gt 10485760 ]; then
            mv "$log_file" "${log_file}.$(date +%Y%m%d_%H%M%S)"
            gzip "${log_file}.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        fi
    done
    
    # Rotate Docker logs
    docker logs --tail=0 $(docker ps -q) 2>/dev/null || true
    
    info "Log rotation completed"
}

update_system() {
    info "Checking for system updates..."
    
    # Check for security updates
    if apt list --upgradable 2>/dev/null | grep -q security; then
        warning "Security updates available"
        send_alert "Security updates available" "INFO"
    fi
    
    info "System update check completed"
}

# Health check and auto-repair functions
health_check() {
    local issues=0
    
    info "Starting comprehensive health check..."
    
    check_cpu_usage || ((issues++))
    check_memory_usage || ((issues++))
    check_disk_usage || ((issues++))
    check_service_health || ((issues++))
    check_mount_points || ((issues++))
    check_network_connectivity || ((issues++))
    
    if [ $issues -eq 0 ]; then
        info "Health check passed - all systems operational"
        return 0
    else
        warning "Health check found $issues issues"
        return 1
    fi
}

auto_repair() {
    info "Attempting auto-repair..."
    
    # Restart services if needed
    if [ -f "$DEPLOY_DIR/docker-compose.prod.yml" ]; then
        cd "$DEPLOY_DIR"
        
        if ! docker-compose -f docker-compose.prod.yml ps | grep -q "Up"; then
            info "Restarting all services..."
            docker-compose -f docker-compose.prod.yml restart
            sleep 30
        fi
    fi
    
    # Remount if needed
    if ! mountpoint -q "/mnt/$PROJECT_NAME" 2>/dev/null; then
        info "Attempting to remount external storage..."
        mount -a 2>/dev/null || true
    fi
    
    # Clean up if disk space is low
    local disk_usage
    disk_usage=$(df "$DATA_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        info "Running emergency cleanup..."
        cleanup_temp_files
        docker system prune -a -f >/dev/null 2>&1 || true
    fi
    
    info "Auto-repair completed"
}

# Report generation
generate_report() {
    local report_file="$LOG_DIR/daily-report-$(date +%Y%m%d).txt"
    
    {
        echo "=== $PROJECT_NAME Daily Report - $(date) ==="
        echo ""
        echo "System Information:"
        echo "  Uptime: $(uptime -p)"
        echo "  Kernel: $(uname -r)"
        echo "  OS: $(lsb_release -d | cut -f2)"
        echo ""
        echo "Resource Usage:"
        echo "  CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')%"
        echo "  Memory: $(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
        echo "  Disk: $(df "$DATA_DIR" | awk 'NR==2 {print $5}')"
        echo ""
        echo "Service Status:"
        if [ -f "$DEPLOY_DIR/docker-compose.prod.yml" ]; then
            cd "$DEPLOY_DIR"
            docker-compose -f docker-compose.prod.yml ps
        fi
        echo ""
        echo "Recent Alerts:"
        tail -20 "$LOG_DIR/monitoring.log" 2>/dev/null || echo "No recent alerts"
        echo ""
        echo "=== End of Report ==="
    } > "$report_file"
    
    info "Daily report generated: $report_file"
}

# Main execution
main() {
    local action="${1:-check}"
    
    case "$action" in
        "check")
            health_check
            ;;
        "repair")
            auto_repair
            ;;
        "cleanup")
            cleanup_temp_files
            optimize_database
            rotate_logs
            ;;
        "report")
            generate_report
            ;;
        "full")
            health_check
            if [ $? -ne 0 ]; then
                auto_repair
                sleep 60
                health_check
            fi
            cleanup_temp_files
            optimize_database
            rotate_logs
            update_system
            generate_report
            ;;
        *)
            echo "Usage: $0 {check|repair|cleanup|report|full}"
            echo "  check   - Run health check"
            echo "  repair  - Attempt auto-repair"
            echo "  cleanup - Run maintenance cleanup"
            echo "  report  - Generate daily report"
            echo "  full    - Run complete monitoring and maintenance"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"