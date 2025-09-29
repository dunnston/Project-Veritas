\# GitHub PR Automation Guide



\## 🚀 Automated Workflow Overview



This repository uses GitHub Actions and helper scripts to automate the PR process. When working on features, follow these guidelines for seamless automation.



\## 📋 Branch Naming Convention



Use the format: `\[type]/\[feature-name]`



\### Supported Types:

\- `feature/` - New features → Creates "feat:" PRs

\- `fix/` - Bug fixes → Creates "fix:" PRs  

\- `docs/` - Documentation → Creates "docs:" PRs

\- `refactor/` - Code refactoring → Creates "refactor:" PRs

\- `test/` - Test improvements → Creates "test:" PRs

\- `chore/` - Maintenance tasks → Creates "chore:" PRs



\### Examples:

```

feature/user-authentication

fix/payment-validation-bug

docs/api-documentation-update

refactor/database-optimization

```



\## 🤖 Automated PR Creation



\### Method 1: Helper Script (Recommended)

```bash

\# Interactive mode

./scripts/create-pr.sh



\# With parameters

./scripts/create-pr.sh feature "user dashboard" "Add analytics dashboard for users"

```



\### Method 2: Manual Branch Push

```bash

git checkout main

git pull origin main

git checkout -b feature/your-feature-name

git push -u origin feature/your-feature-name

\# PR automatically created on first push!

```



\## 📝 Commit Message Format



Use \[conventional commits](https://www.conventionalcommits.org/) for automatic changelog generation:



```bash

feat: add user authentication system

feat(auth): implement OAuth login flow

fix: resolve payment validation issue

fix(api): handle null response edge case

docs: update installation instructions

refactor: simplify database query logic

test: add unit tests for auth module

chore: update dependencies

```



\## 🔄 Automated Checks



Every PR automatically runs:

\- ✅ Code linting and formatting checks

\- ✅ Unit test suite

\- ✅ Build verification

\- ✅ Security scanning (if configured)

\- ✅ Branch protection rules



\## 📋 PR Template Structure



All PRs automatically include:

\- 🚀 \*\*Description\*\* - Auto-filled from commit/branch info

\- 📋 \*\*Type of Change\*\* - Checkboxes for change type

\- 🧪 \*\*Testing\*\* - Testing checklist

\- 📸 \*\*Screenshots\*\* - For UI changes

\- 🔗 \*\*Related Issues\*\* - Link to issues

\- ✅ \*\*Review Checklist\*\* - Code review items



\## ⚡ Quick Commands



\### Using npm scripts:

```bash

npm run pr:create          # Create new PR interactively

npm run pr:view            # View current PR details

npm run pr:ready           # Mark draft PR as ready for review

npm run lint               # Run code linting

npm run format             # Format code

npm run test               # Run test suite

```



\### Using GitHub CLI directly:

```bash

gh pr create               # Create PR manually

gh pr view                 # View PR details

gh pr ready                # Mark draft as ready

gh pr merge                # Merge when ready

gh pr close                # Close PR

```



\## 🛡️ Branch Protection Rules



\### Main Branch Protection:

\- ✅ Require PR before merging

\- ✅ Require status checks to pass

\- ✅ Require branches to be up to date

\- ✅ Require conversation resolution

\- ✅ Auto-delete head branches after merge



\### Auto-merge Conditions:

\- All required checks pass

\- At least one approval (if required)

\- No requested changes

\- Branch is up to date



\## 🚨 Hotfix Process



For urgent production fixes:

```bash

git checkout main

git pull origin main

git checkout -b hotfix/critical-bug-description

\# Make minimal necessary changes

git commit -m "hotfix: resolve critical production issue"

git push -u origin hotfix/critical-bug-description

```



\## 🎯 Best Practices



\### DO:

\- ✅ Use descriptive branch names

\- ✅ Write clear commit messages

\- ✅ Keep PRs focused and small

\- ✅ Update tests for new features

\- ✅ Respond to review comments promptly

\- ✅ Use draft PRs for work-in-progress



\### DON'T:

\- ❌ Push directly to main/master

\- ❌ Create massive PRs with multiple features

\- ❌ Skip writing tests

\- ❌ Ignore linting/formatting errors

\- ❌ Force push to shared branches



\## 🔧 Troubleshooting



\### Common Issues:



\*\*PR not created automatically:\*\*

\- Check branch naming follows `type/feature-name` format

\- Ensure you're not pushing to main/master

\- Verify GitHub Actions are enabled



\*\*Checks failing:\*\*

```bash

npm run lint              # Fix linting issues

npm run format            # Fix formatting

npm test                  # Run tests locally

```



\*\*Permission denied on scripts:\*\*

```bash

chmod +x scripts/create-pr.sh

```



\*\*GitHub CLI not authenticated:\*\*

```bash

gh auth login

gh auth status            # Verify authentication

```



\## 📁 File Structure



```

├── .github/

│   ├── workflows/

│   │   └── pr-automation.yml     # Main automation workflow

│   └── pull\_request\_template.md  # PR template

├── scripts/

│   └── create-pr.sh              # PR creation helper

└── GITHUB.md                     # This file

```



\## 🚀 Advanced Features



\### Semantic Release (Optional)

Automatically generates releases based on commit messages:

```json

{

&nbsp; "release": {

&nbsp;   "branches": \["main"],

&nbsp;   "plugins": \[

&nbsp;     "@semantic-release/commit-analyzer",

&nbsp;     "@semantic-release/release-notes-generator",

&nbsp;     "@semantic-release/github"

&nbsp;   ]

&nbsp; }

}

```



\### Dependabot Configuration

Automatic dependency updates:

```yaml

\# .github/dependabot.yml

version: 2

updates:

&nbsp; - package-ecosystem: "npm"

&nbsp;   directory: "/"

&nbsp;   schedule:

&nbsp;     interval: "weekly"

&nbsp;   open-pull-requests-limit: 5

```



\### CodeQL Security Scanning

```yaml

\# Add to .github/workflows/codeql.yml

name: "CodeQL"

on:

&nbsp; push:

&nbsp;   branches: \[ main ]

&nbsp; pull\_request:

&nbsp;   branches: \[ main ]

jobs:

&nbsp; analyze:

&nbsp;   runs-on: ubuntu-latest

&nbsp;   steps:

&nbsp;   - uses: actions/checkout@v4

&nbsp;   - uses: github/codeql-action/init@v2

&nbsp;   - uses: github/codeql-action/analyze@v2

```



---



\## 🤝 Team Collaboration



\### For Multiple Contributors:

1\. Always pull latest changes before starting work

2\. Use meaningful commit messages for better history

3\. Keep PRs small and focused for easier review

4\. Use GitHub's review features effectively

5\. Communicate through PR comments and issues



\### Review Process:

1\. PR created automatically with template

2\. Automated checks run

3\. Team member reviews code

4\. Address feedback and push updates

5\. Auto-merge when approved and checks pass



---



\*This automation setup ensures consistent, high-quality PRs with minimal manual overhead!\* 🎉

