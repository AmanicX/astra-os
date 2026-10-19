#!/usr/bin/env bash
# AstraOS Git Setup Assistant
# This script automates the creation of SSH keys and linking the project to GitHub.
set -Eeuo pipefail

echo "----------------------------------------------------------------"
echo "  AstraOS Git Setup Assistant"
echo "----------------------------------------------------------------"

# 1. Identify the user
read -p "Enter your GitHub username: " GH_USER
[[ -z "$GH_USER" ]] && { echo "Username is required"; exit 1; }

# 2. Setup Git Identity (Local)
git config user.name "AstraOS Build Bot"
git config user.email "build@astraos.org"
echo "==> Local git identity configured."

# 3. Generate SSH Key if it doesn't exist
if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
    echo "==> Generating new SSH key..."
    ssh-keygen -t ed25519 -C "build@astraos.org" -N "" -f "$HOME/.ssh/id_ed25519"
    echo "==> SSH key generated."
else
    echo "==> SSH key already exists. Skipping generation."
fi

# 4. Add Remote Origin
# We use the SSH URL since we are setting up keys.
REMOTE_URL="git@github.com:${GH_USER}/astra-os.git"
if git remote | grep -q "origin"; then
    echo "==> Remote 'origin' already exists. Updating URL..."
    git remote set-url origin "$REMOTE_URL"
else
    echo "==> Adding remote origin..."
    git remote add origin "$REMOTE_URL"
fi

# 5. Branching
if [[ "$(git branch --show-current)" != "pre-release-testing" ]]; then
    echo "==> Switching to 'pre-release-testing' branch..."
    git checkout -b pre-release-testing
fi

echo ""
echo "----------------------------------------------------------------"
echo "STEP 1: COPY THE KEY BELOW TO GITHUB"
echo "----------------------------------------------------------------"
echo "Go to: https://github.com/${GH_USER}/settings/keys"
echo "Click 'New SSH Key', give it a title, and paste this entire line:"
echo ""
cat "$HOME/.ssh/id_ed25519.pub"
echo ""
echo "----------------------------------------------------------------"
echo "STEP 2: PUSH THE CODE"
echo "----------------------------------------------------------------"
echo "Once you have added the key to GitHub, run the following command:"
echo "  git push -u origin pre-release-testing"
echo ""
echo "Or simply run this script again to try and push automatically."
echo "----------------------------------------------------------------"

# Try to push automatically
echo "Attempting to push now..."
if git push -u origin pre-release-testing 2>/dev/null; then
    echo "==> SUCCESS! Code pushed to GitHub."
else
    echo "==> Push failed. This is normal if you haven't added the key to GitHub yet."
    echo "    Please add the key to GitHub and run this script again."
fi
