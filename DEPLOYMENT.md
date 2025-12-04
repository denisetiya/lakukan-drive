# Lakukan Drive - CI/CD dan Deployment Guide

## Overview

Dokumen ini menjelaskan cara setup CI/CD pipeline untuk Lakukan Drive menggunakan GitHub Actions dan deployment ke VPS dengan Docker.

## Struktur CI/CD

### GitHub Actions Workflow

Project ini memiliki beberapa workflow:

1. **CI Pipeline** (`.github/workflows/ci.yaml`) - Build, lint, dan test
2. **Docker Build** (`.github/workflows/docker-build.yml`) - Build dan push Docker images
3. **PR Lint** (`.github/workflows/lint-pr.yaml`) - Validasi pull request

### Docker Images

- **Frontend**: `ghcr.io/[username]/lakukan-drive-frontend`
- **Backend**: `ghcr.io/[username]/lakukan-drive-backend`

## Setup GitHub Secrets

Tambahkan secrets berikut di repository GitHub:

```
VPS_HOST=your-vps-ip-address
VPS_USERNAME=lakukan-user
VPS_SSH_KEY=-----BEGIN OPENSSH PRIVATE KEY-----
... your private key content ...
-----END OPENSSH PRIVATE KEY-----
GITHUB_TOKEN=your-github-token
```

## Setup VPS

### 1. Initial Setup

Clone repository dan jalankan setup script:

```bash
# Clone repository
git clone https://github.com/username/lakukan-drive.git
cd lakukan-drive

# Jalankan VPS setup (run as root)
sudo bash scripts/setup-vps.sh
```

### 2. Setup Storage

Pilih salah satu opsi storage:

#### Local Storage (Default)
```bash
sudo bash scripts/setup-mounts.sh
```

#### External Storage
```bash
sudo bash scripts/setup-mounts.sh /dev/sdb1 external
```

#### NFS Storage
```bash
sudo bash scripts/setup-mounts.sh "" nfs nfs-server-ip /path/to/share
```

#### Cloud Storage
```bash
sudo bash scripts/setup-mounts.sh "" cloud

# Configure rclone
sudo -u lakukan-user rclone config
sudo systemctl start lakukan-drive-cloud-mount
```

### 3. Deployment

Switch ke deploy user dan jalankan deployment:

```bash
# Switch ke deploy user
su - lakukan-user

# Copy konfigurasi ke deployment directory
cp -r /path/to/lakukan-drive/* /opt/lakukan-drive/

# Jalankan deployment
bash /opt/lakukan-drive/scripts/deploy.sh
```

## Development

### Local Development

Gunakan Docker Compose untuk development:

```bash
# Start development environment
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.dev.yml logs -f

# Stop services
docker-compose -f docker-compose.dev.yml down
```

### Build Manual

```bash
# Build frontend
cd frontend
pnpm install
pnpm run build

# Build backend
cd ..
task build:backend

# Build Docker images
docker build -t lakukan-drive-frontend ./frontend
docker build -t lakukan-drive-backend .
```

## Production Deployment

### Docker Compose Production

File `docker-compose.prod.yml` digunakan untuk production:

```bash
# Start production services
docker-compose -f docker-compose.prod.yml up -d

# Check service status
docker-compose -f docker-compose.prod.yml ps

# View logs
docker-compose -f docker-compose.prod.yml logs -f

# Update services
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d
```

### SSL Configuration

1. Install SSL certificate:

```bash
# Menggunakan Let's Encrypt
sudo certbot --nginx -d yourdomain.com
```

2. Update nginx configuration di `nginx/proxy.conf`

### Monitoring

System monitoring otomatis sudah di-setup:

```bash
# Check monitoring logs
tail -f /var/log/lakukan-drive/monitor.log

# Check disk usage
df -h | grep lakukan-drive

# Check service status
systemctl status lakukan-drive
```

## Backup dan Restore

### Backup Otomatis

Backup dijalankan setiap hari jam 2 AM:

```bash
# Manual backup
/usr/local/bin/lakukan-drive-backup.sh

# List backups
ls -la /opt/backups/lakukan-drive/
```

### Restore

```bash
# Stop services
docker-compose -f /opt/lakukan-drive/docker-compose.prod.yml down

# Restore dari backup
cd /opt/backups/lakukan-drive/backup-YYYYMMDD-HHMMSS
tar -xzf data.tar.gz -C /opt/data/lakukan-drive/

# Start services
docker-compose -f /opt/lakukan-drive/docker-compose.prod.yml up -d
```

## Troubleshooting

### Common Issues

1. **Services tidak start**
   ```bash
   # Check logs
   docker-compose -f docker-compose.prod.yml logs
   
   # Check disk space
   df -h
   
   # Check memory
   free -h
   ```

2. **Mount issues**
   ```bash
   # Check mount status
   mount | grep lakukan-drive
   
   # Remount manual
   sudo mount -a
   ```

3. **Permission issues**
   ```bash
   # Fix ownership
   sudo chown -R lakukan-user:lakukan-user /opt/data/lakukan-drive
   sudo chown -R lakukan-user:lakukan-user /opt/lakukan-drive
   ```

### Performance Optimization

1. **Disk I/O optimization**
   ```bash
   # Check disk performance
   iostat -x 1
   
   # Optimize fstab settings
   sudo nano /etc/fstab
   ```

2. **Memory optimization**
   ```bash
   # Check memory usage
   free -h
   top
   
   # Adjust swap if needed
   sudo swapon --show
   ```

## Security

### Firewall Configuration

Firewall otomatis di-setup dengan rules:
- SSH (22)
- HTTP (80)
- HTTPS (443)

```bash
# Check firewall status
sudo ufw status

# Add custom rules
sudo ufw allow 8080/tcp
```

### SSL/TLS

Gunakan SSL certificate untuk production:
- Let's Encrypt (gratis)
- Custom certificate

### User Access

- Deploy user: `lakukan-user`
- SSH key authentication
- Sudo access terbatas

## Maintenance

### Regular Tasks

1. **Update system** (mingguan)
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **Clean Docker images** (bulanan)
   ```bash
   docker system prune -a
   ```

3. **Check logs** (harian)
   ```bash
   tail -f /var/log/lakukan-drive/*.log
   ```

### Monitoring Metrics

Monitor metrics berikut:
- CPU usage
- Memory usage
- Disk usage
- Network traffic
- Service health

## CI/CD Pipeline Flow

```
Push to main branch
    ↓
GitHub Actions triggers
    ↓
Build frontend Docker image
    ↓
Build backend Docker image
    ↓
Push to GitHub Container Registry
    ↓
Deploy to VPS via SSH
    ↓
Pull latest images
    ↓
Restart services
    ↓
Health check
```

## Environment Variables

### Production Environment

```bash
GITHUB_REPOSITORY_OWNER=your-username
COMPOSE_PROJECT_NAME=lakukan-drive
NODE_ENV=production
```

### Development Environment

```bash
NODE_ENV=development
```

## Support

Untuk issues atau questions:
1. Check logs di `/var/log/lakukan-drive/`
2. Check GitHub Actions logs
3. Create issue di repository