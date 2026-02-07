#!/bin/bash

# Rollback Script for Node.js Applications
# Quickly revert to a previous release

set -e

# Configuration
ENVIRONMENT="${1:-staging}"
RELEASE_VERSION="${2}"
APP_NAME="my-app"
REMOTE_USER="${DEPLOY_USER:-deploy}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Environment configuration
case $ENVIRONMENT in
    staging)
        REMOTE_HOST="${STAGING_SERVER}"
        REMOTE_PATH="/var/www/${APP_NAME}/staging"
        PM2_APP_NAME="${APP_NAME}-staging"
        HEALTH_CHECK_URL="https://staging.example.com/health"
        ;;
    production)
        REMOTE_HOST="${PRODUCTION_SERVER}"
        REMOTE_PATH="/var/www/${APP_NAME}/production"
        PM2_APP_NAME="${APP_NAME}-production"
        HEALTH_CHECK_URL="https://example.com/health"
        ;;
    *)
        log_error "Invalid environment: $ENVIRONMENT"
        echo "Usage: $0 {staging|production} [release_version]"
        exit 1
        ;;
esac

# Validation
if [ -z "$REMOTE_HOST" ]; then
    log_error "REMOTE_HOST is not set"
    exit 1
fi

log_warn "========================================="
log_warn "ROLLBACK INITIATED FOR: $ENVIRONMENT"
log_warn "========================================="

# If no release version specified, show available releases
if [ -z "$RELEASE_VERSION" ]; then
    log_info "Available releases:"
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "
        cd ${REMOTE_PATH}/releases 2>/dev/null && ls -t || echo 'No releases found'
    "
    
    log_info ""
    log_info "Available backups:"
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "
        cd ${REMOTE_PATH} 2>/dev/null && ls -dt backup_* 2>/dev/null || echo 'No backups found'
    "
    
    echo ""
    log_error "Please specify a release version or backup to rollback to:"
    echo "Usage: $0 $ENVIRONMENT <release_version|backup_YYYYMMDD_HHMMSS>"
    exit 1
fi

# Determine rollback target
if [[ $RELEASE_VERSION == backup_* ]]; then
    ROLLBACK_PATH="${REMOTE_PATH}/${RELEASE_VERSION}"
    log_info "Rolling back to backup: $RELEASE_VERSION"
else
    ROLLBACK_PATH="${REMOTE_PATH}/releases/${RELEASE_VERSION}"
    log_info "Rolling back to release: $RELEASE_VERSION"
fi

# Verify rollback target exists
log_info "Verifying rollback target..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "
    if [ ! -d ${ROLLBACK_PATH} ]; then
        echo 'ERROR: Rollback target not found: ${ROLLBACK_PATH}'
        exit 1
    fi
"

if [ $? -ne 0 ]; then
    log_error "Rollback target verification failed"
    exit 1
fi

# Confirmation prompt
echo ""
log_warn "You are about to rollback $ENVIRONMENT to: $RELEASE_VERSION"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    log_info "Rollback cancelled"
    exit 0
fi

# Get current release for backup
log_info "Backing up current state..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ssh "${REMOTE_USER}@${REMOTE_HOST}" "
    if [ -L ${REMOTE_PATH}/current ]; then
        CURRENT_TARGET=\$(readlink ${REMOTE_PATH}/current)
        cp -r \${CURRENT_TARGET} ${REMOTE_PATH}/rollback_backup_${TIMESTAMP}
        echo 'Current state backed up to: rollback_backup_${TIMESTAMP}'
    fi
"

# Update symlink to rollback target
log_info "Updating symlink to rollback target..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "
    ln -sfn ${ROLLBACK_PATH} ${REMOTE_PATH}/current
    echo 'Symlink updated to: ${ROLLBACK_PATH}'
"

# Restart application
log_info "Restarting application..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "
    cd ${REMOTE_PATH}/current
    pm2 restart ${PM2_APP_NAME}
    pm2 save
"

# Wait for application to start
log_info "Waiting for application to restart..."
sleep 10

# Health check
log_info "Running health check..."
MAX_ATTEMPTS=5
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    log_info "Health check attempt $ATTEMPT/$MAX_ATTEMPTS..."
    
    if curl -f -s --max-time 10 "$HEALTH_CHECK_URL" > /dev/null; then
        log_info "${GREEN}✓${NC} Health check passed!"
        break
    else
        if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
            log_error "Health check failed after rollback!"
            log_error "Manual intervention required"
            
            # Send alert
            if [ -n "$SLACK_WEBHOOK_URL" ]; then
                curl -X POST -H 'Content-type: application/json' \
                    --data "{
                        \"text\": \"⚠️ CRITICAL: Rollback health check failed on *${ENVIRONMENT}*\",
                        \"attachments\": [{
                            \"color\": \"danger\",
                            \"fields\": [
                                {\"title\": \"Environment\", \"value\": \"${ENVIRONMENT}\"},
                                {\"title\": \"Rollback Version\", \"value\": \"${RELEASE_VERSION}\"},
                                {\"title\": \"Status\", \"value\": \"Health check failed\"}
                            ]
                        }]
                    }" \
                    "$SLACK_WEBHOOK_URL" 2>/dev/null || true
            fi
            
            exit 1
        fi
        
        log_warn "Health check failed, retrying..."
        sleep 10
        ATTEMPT=$((ATTEMPT + 1))
    fi
done

# Success
log_info "${GREEN}=========================================${NC}"
log_info "${GREEN}Rollback completed successfully!${NC}"
log_info "${GREEN}=========================================${NC}"
log_info "Environment: $ENVIRONMENT"
log_info "Rollback to: $RELEASE_VERSION"
log_info "Application URL: $HEALTH_CHECK_URL"

# Send success notification
if [ -n "$SLACK_WEBHOOK_URL" ]; then
    curl -X POST -H 'Content-type: application/json' \
        --data "{
            \"text\": \"Rollback completed on *${ENVIRONMENT}*\",
            \"attachments\": [{
                \"color\": \"warning\",
                \"fields\": [
                    {\"title\": \"Environment\", \"value\": \"${ENVIRONMENT}\", \"short\": true},
                    {\"title\": \"Rollback Version\", \"value\": \"${RELEASE_VERSION}\", \"short\": true},
                    {\"title\": \"Status\", \"value\": \"✓ Success\", \"short\": true}
                ]
            }]
        }" \
        "$SLACK_WEBHOOK_URL" 2>/dev/null || true
fi

exit 0
