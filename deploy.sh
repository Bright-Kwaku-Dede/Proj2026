#!/bin/bash

# Deployment Script for Node.js Applications
# This script handles deployment to remote servers via SSH

set -e  # Exit on error

# Configuration
ENVIRONMENT="${1:-staging}"
APP_NAME="my-app"
REMOTE_USER="${DEPLOY_USER:-deploy}"
BUILD_DIR="dist"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Environment-specific configuration
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
        echo "Usage: $0 {staging|production}"
        exit 1
        ;;
esac

# Validation
if [ -z "$REMOTE_HOST" ]; then
    log_error "REMOTE_HOST is not set for environment: $ENVIRONMENT"
    exit 1
fi

if [ ! -d "$BUILD_DIR" ]; then
    log_error "Build directory not found: $BUILD_DIR"
    exit 1
fi

log_info "Starting deployment to $ENVIRONMENT environment..."
log_info "Remote host: $REMOTE_HOST"
log_info "Remote path: $REMOTE_PATH"

# Create backup of current deployment
log_info "Creating backup of current deployment..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "
    if [ -d ${REMOTE_PATH}/current ]; then
        cp -r ${REMOTE_PATH}/current ${REMOTE_PATH}/backup_${TIMESTAMP}
        echo 'Backup created: backup_${TIMESTAMP}'
    else
        echo 'No existing deployment to backup'
    fi
"

# Create release directory
RELEASE_DIR="${REMOTE_PATH}/releases/${TIMESTAMP}"
log_info "Creating release directory: $RELEASE_DIR"
ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${RELEASE_DIR}"

# Upload build files
log_info "Uploading build files..."
rsync -avz --delete \
    -e "ssh" \
    ${BUILD_DIR}/ \
    "${REMOTE_USER}@${REMOTE_HOST}:${RELEASE_DIR}/"

# Upload package files and install production dependencies
log_info "Installing production dependencies..."
scp package.json package-lock.json "${REMOTE_USER}@${REMOTE_HOST}:${RELEASE_DIR}/"
ssh "${REMOTE_USER}@${REMOTE_HOST}" "
    cd ${RELEASE_DIR}
    npm ci --production --silent
"

# Copy environment variables
log_info "Setting up environment variables..."
if [ "$ENVIRONMENT" == "staging" ] && [ -n "$STAGING_ENV_FILE" ]; then
    scp "$STAGING_ENV_FILE" "${REMOTE_USER}@${REMOTE_HOST}:${RELEASE_DIR}/.env"
elif [ "$ENVIRONMENT" == "production" ] && [ -n "$PRODUCTION_ENV_FILE" ]; then
    scp "$PRODUCTION_ENV_FILE" "${REMOTE_USER}@${REMOTE_HOST}:${RELEASE_DIR}/.env"
fi

# Update symlink to new release
log_info "Updating symlink to new release..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "
    ln -sfn ${RELEASE_DIR} ${REMOTE_PATH}/current
    echo 'Symlink updated to: ${RELEASE_DIR}'
"

# Restart application
log_info "Restarting application with PM2..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "
    cd ${REMOTE_PATH}/current
    pm2 restart ${PM2_APP_NAME} --update-env || pm2 start ecosystem.config.js --env ${ENVIRONMENT}
    pm2 save
"

# Wait for application to start
log_info "Waiting for application to start..."
sleep 10

# Health check
log_info "Running health check..."
MAX_ATTEMPTS=5
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    log_info "Health check attempt $ATTEMPT/$MAX_ATTEMPTS..."
    
    if curl -f -s --max-time 10 "$HEALTH_CHECK_URL" > /dev/null; then
        log_info "Health check passed!"
        break
    else
        if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
            log_error "Health check failed after $MAX_ATTEMPTS attempts"
            
            # Rollback
            log_warn "Initiating rollback..."
            ssh "${REMOTE_USER}@${REMOTE_HOST}" "
                if [ -d ${REMOTE_PATH}/backup_${TIMESTAMP} ]; then
                    ln -sfn ${REMOTE_PATH}/backup_${TIMESTAMP} ${REMOTE_PATH}/current
                    pm2 restart ${PM2_APP_NAME}
                    echo 'Rollback completed'
                fi
            "
            exit 1
        fi
        
        log_warn "Health check failed, retrying in 10 seconds..."
        sleep 10
        ATTEMPT=$((ATTEMPT + 1))
    fi
done

# Cleanup old releases (keep last 5)
log_info "Cleaning up old releases..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "
    cd ${REMOTE_PATH}/releases
    ls -t | tail -n +6 | xargs -r rm -rf
    echo 'Old releases cleaned up'
"

# Cleanup old backups (keep last 3)
log_info "Cleaning up old backups..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "
    cd ${REMOTE_PATH}
    ls -dt backup_* 2>/dev/null | tail -n +4 | xargs -r rm -rf || true
    echo 'Old backups cleaned up'
"

log_info "Deployment to $ENVIRONMENT completed successfully!"
log_info "Release: $TIMESTAMP"
log_info "Application is running at: $HEALTH_CHECK_URL"

# Send notification (optional)
if [ -n "$SLACK_WEBHOOK_URL" ]; then
    log_info "Sending Slack notification..."
    curl -X POST -H 'Content-type: application/json' \
        --data "{
            \"text\": \"Deployment to *${ENVIRONMENT}* completed successfully!\",
            \"attachments\": [{
                \"color\": \"good\",
                \"fields\": [
                    {\"title\": \"Environment\", \"value\": \"${ENVIRONMENT}\", \"short\": true},
                    {\"title\": \"Release\", \"value\": \"${TIMESTAMP}\", \"short\": true}
                ]
            }]
        }" \
        "$SLACK_WEBHOOK_URL"
fi

exit 0
