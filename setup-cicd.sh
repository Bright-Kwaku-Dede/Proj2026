#!/bin/bash

# CI/CD Setup Script
# Automates the initial setup of CI/CD infrastructure

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}CI/CD Setup Script${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Detect CI platform
detect_platform() {
    echo -e "${YELLOW}Select your CI/CD platform:${NC}"
    echo "1) GitHub Actions"
    echo "2) GitLab CI/CD"
    echo "3) Jenkins"
    echo "4) CircleCI"
    echo "5) All (create configs for all platforms)"
    read -p "Enter choice [1-5]: " PLATFORM_CHOICE
}

# Create directory structure
create_directories() {
    echo -e "${GREEN}Creating directory structure...${NC}"
    
    mkdir -p .github/workflows
    mkdir -p scripts
    mkdir -p .ci
    mkdir -p tests/unit
    mkdir -p tests/integration
    mkdir -p tests/e2e
    
    echo -e "${GREEN}✓ Directories created${NC}"
}

# Setup GitHub Actions
setup_github_actions() {
    echo -e "${GREEN}Setting up GitHub Actions...${NC}"
    
    if [ ! -f ".github/workflows/ci-cd.yml" ]; then
        cat > .github/workflows/ci-cd.yml << 'EOF'
name: CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
      - run: npm ci
      - run: npm test

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '18'
      - run: npm ci
      - run: npm run build
      - uses: actions/upload-artifact@v3
        with:
          name: dist
          path: dist/

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/download-artifact@v3
        with:
          name: dist
      - name: Deploy
        run: echo "Add your deployment commands here"
EOF
        echo -e "${GREEN}✓ GitHub Actions workflow created${NC}"
    else
        echo -e "${YELLOW}GitHub Actions workflow already exists${NC}"
    fi
}

# Setup GitLab CI
setup_gitlab_ci() {
    echo -e "${GREEN}Setting up GitLab CI/CD...${NC}"
    
    if [ ! -f ".gitlab-ci.yml" ]; then
        cat > .gitlab-ci.yml << 'EOF'
stages:
  - test
  - build
  - deploy

test:
  stage: test
  image: node:18
  script:
    - npm ci
    - npm test

build:
  stage: build
  image: node:18
  script:
    - npm ci
    - npm run build
  artifacts:
    paths:
      - dist/

deploy:
  stage: deploy
  script:
    - echo "Add your deployment commands here"
  only:
    - main
EOF
        echo -e "${GREEN}✓ GitLab CI configuration created${NC}"
    else
        echo -e "${YELLOW}GitLab CI configuration already exists${NC}"
    fi
}

# Setup Jenkins
setup_jenkins() {
    echo -e "${GREEN}Setting up Jenkins...${NC}"
    
    if [ ! -f "Jenkinsfile" ]; then
        cat > Jenkinsfile << 'EOF'
pipeline {
    agent any
    
    stages {
        stage('Test') {
            steps {
                sh 'npm ci'
                sh 'npm test'
            }
        }
        
        stage('Build') {
            steps {
                sh 'npm run build'
            }
        }
        
        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                echo 'Add your deployment commands here'
            }
        }
    }
}
EOF
        echo -e "${GREEN}✓ Jenkinsfile created${NC}"
    else
        echo -e "${YELLOW}Jenkinsfile already exists${NC}"
    fi
}

# Setup CircleCI
setup_circleci() {
    echo -e "${GREEN}Setting up CircleCI...${NC}"
    
    mkdir -p .circleci
    
    if [ ! -f ".circleci/config.yml" ]; then
        cat > .circleci/config.yml << 'EOF'
version: 2.1

jobs:
  test:
    docker:
      - image: cimg/node:18.17
    steps:
      - checkout
      - run: npm ci
      - run: npm test

  build:
    docker:
      - image: cimg/node:18.17
    steps:
      - checkout
      - run: npm ci
      - run: npm run build

  deploy:
    docker:
      - image: cimg/node:18.17
    steps:
      - run: echo "Add your deployment commands here"

workflows:
  build-test-deploy:
    jobs:
      - test
      - build:
          requires:
            - test
      - deploy:
          requires:
            - build
          filters:
            branches:
              only: main
EOF
        echo -e "${GREEN}✓ CircleCI configuration created${NC}"
    else
        echo -e "${YELLOW}CircleCI configuration already exists${NC}"
    fi
}

# Create package.json scripts
setup_npm_scripts() {
    echo -e "${GREEN}Setting up npm scripts...${NC}"
    
    # Check if package.json exists
    if [ ! -f "package.json" ]; then
        npm init -y
    fi
    
    # Add CI/CD related scripts
    node -e "
    const fs = require('fs');
    const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
    
    pkg.scripts = pkg.scripts || {};
    pkg.scripts.test = pkg.scripts.test || 'echo \"Error: no test specified\" && exit 1';
    pkg.scripts['test:unit'] = 'echo \"Add unit test command\"';
    pkg.scripts['test:integration'] = 'echo \"Add integration test command\"';
    pkg.scripts['test:e2e'] = 'echo \"Add e2e test command\"';
    pkg.scripts['test:coverage'] = 'echo \"Add coverage command\"';
    pkg.scripts.lint = 'echo \"Add linting command\"';
    pkg.scripts.build = 'echo \"Add build command\"';
    pkg.scripts.start = 'echo \"Add start command\"';
    pkg.scripts.dev = 'echo \"Add dev command\"';
    
    fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
    "
    
    echo -e "${GREEN}✓ npm scripts configured${NC}"
}

# Create deployment scripts
create_deployment_scripts() {
    echo -e "${GREEN}Creating deployment scripts...${NC}"
    
    # Make scripts executable
    chmod +x scripts/*.sh 2>/dev/null || true
    
    echo -e "${GREEN}✓ Deployment scripts ready${NC}"
}

# Setup Docker
setup_docker() {
    echo -e "${GREEN}Setting up Docker configuration...${NC}"
    
    if [ ! -f "Dockerfile" ]; then
        cat > Dockerfile << 'EOF'
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY package*.json ./
EXPOSE 3000
CMD ["node", "dist/index.js"]
EOF
        echo -e "${GREEN}✓ Dockerfile created${NC}"
    fi
    
    if [ ! -f ".dockerignore" ]; then
        cat > .dockerignore << 'EOF'
node_modules
npm-debug.log
.git
.gitignore
README.md
.env
.env.local
dist
coverage
.DS_Store
EOF
        echo -e "${GREEN}✓ .dockerignore created${NC}"
    fi
}

# Create environment files templates
create_env_templates() {
    echo -e "${GREEN}Creating environment file templates...${NC}"
    
    if [ ! -f ".env.example" ]; then
        cat > .env.example << 'EOF'
# Application
NODE_ENV=development
PORT=3000

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/dbname

# Redis
REDIS_URL=redis://localhost:6379

# API Keys
API_KEY=your_api_key_here

# Deployment
STAGING_SERVER=staging.example.com
PRODUCTION_SERVER=example.com
DEPLOY_USER=deploy
EOF
        echo -e "${GREEN}✓ .env.example created${NC}"
    fi
}

# Setup Git hooks
setup_git_hooks() {
    echo -e "${GREEN}Setting up Git hooks...${NC}"
    
    if [ -d ".git" ]; then
        # Pre-commit hook
        cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
npm run lint
npm run test:unit
EOF
        chmod +x .git/hooks/pre-commit
        echo -e "${GREEN}✓ Git hooks configured${NC}"
    else
        echo -e "${YELLOW}Not a git repository, skipping git hooks${NC}"
    fi
}

# Main setup flow
main() {
    detect_platform
    create_directories
    
    case $PLATFORM_CHOICE in
        1)
            setup_github_actions
            ;;
        2)
            setup_gitlab_ci
            ;;
        3)
            setup_jenkins
            ;;
        4)
            setup_circleci
            ;;
        5)
            setup_github_actions
            setup_gitlab_ci
            setup_jenkins
            setup_circleci
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
    
    setup_npm_scripts
    create_deployment_scripts
    setup_docker
    create_env_templates
    setup_git_hooks
    
    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}Setup Complete!${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Review and customize the generated CI/CD configurations"
    echo "2. Set up required secrets in your CI/CD platform"
    echo "3. Update deployment scripts with your infrastructure details"
    echo "4. Configure your test commands in package.json"
    echo "5. Commit and push to trigger your first pipeline"
    echo ""
    echo -e "${YELLOW}Important:${NC}"
    echo "- Add sensitive information to .env (not .env.example)"
    echo "- Never commit secrets or .env files to version control"
    echo "- Update the placeholder deployment commands"
    echo ""
}

# Run main function
main
