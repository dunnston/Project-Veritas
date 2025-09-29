#!/bin/bash

# PR Creation and Management Script
# Usage: ./scripts/create-pr.sh [feature-type] [feature-name] [description]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) is not installed. Please install it first:"
    echo "https://cli.github.com/"
    exit 1
fi

# Get parameters
FEATURE_TYPE=${1:-"feature"}
FEATURE_NAME=${2:-""}
DESCRIPTION=${3:-""}

# If no feature name provided, prompt for it
if [ -z "$FEATURE_NAME" ]; then
    echo -n "Enter feature name: "
    read FEATURE_NAME
fi

# If no description provided, prompt for it
if [ -z "$DESCRIPTION" ]; then
    echo -n "Enter brief description: "
    read DESCRIPTION
fi

# Clean feature name (replace spaces with hyphens, lowercase)
CLEAN_FEATURE_NAME=$(echo "$FEATURE_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr '_' '-')
BRANCH_NAME="${FEATURE_TYPE}/${CLEAN_FEATURE_NAME}"

print_status "Creating branch: $BRANCH_NAME"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "Not in a git repository!"
    exit 1
fi

# Ensure we're on main/master and up to date
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
print_status "Switching to $MAIN_BRANCH and pulling latest changes..."

git checkout "$MAIN_BRANCH"
git pull origin "$MAIN_BRANCH"

# Create and checkout new branch
print_status "Creating new branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME"

# Push the branch to origin
print_status "Pushing branch to origin..."
git push -u origin "$BRANCH_NAME"

print_success "Branch '$BRANCH_NAME' created and pushed!"
print_status "You can now start working on your feature."
print_status "When ready, commit your changes and push. A PR will be automatically created."

# Optionally create PR immediately if requested
echo -n "Would you like to create an empty PR now? (y/N): "
read CREATE_PR

if [[ $CREATE_PR =~ ^[Yy]$ ]]; then
    print_status "Creating pull request..."
    
    # Create PR with template
    gh pr create \
        --title "${FEATURE_TYPE}: ${FEATURE_NAME}" \
        --body "## 🚀 Description
${DESCRIPTION}

## 📋 Type of Change
- [ ] 🐛 Bug fix
- [ ] ✨ New feature  
- [ ] 💥 Breaking change
- [ ] 📚 Documentation update
- [ ] 🎨 Style/formatting change
- [ ] ♻️ Code refactor
- [ ] ⚡ Performance improvement

## 🧪 Testing
- [ ] Tests added/updated
- [ ] All tests passing
- [ ] Manual testing completed

## 📝 Additional Notes
Work in progress - will update as development continues.

---
*Created via automation script*" \
        --draft

    print_success "Draft PR created! You can view it with: gh pr view"
fi

print_success "Setup complete! Happy coding! 🚀"