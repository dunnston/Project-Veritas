# Makefile for PR automation commands
.PHONY: pr-create pr-view pr-ready help

# Create a new PR interactively
pr-create:
	@./scripts/create-pr.sh

# View current PR
pr-view:
	@gh pr view

# Mark draft PR as ready for review
pr-ready:
	@gh pr ready

# Show available commands
help:
	@echo "Available commands:"
	@echo "  make pr-create  - Create a new PR interactively"
	@echo "  make pr-view    - View current PR details"
	@echo "  make pr-ready   - Mark draft PR as ready for review"
	@echo ""
	@echo "Direct script usage:"
	@echo "  ./scripts/create-pr.sh [type] [name] [description]"