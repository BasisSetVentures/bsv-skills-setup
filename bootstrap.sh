#!/usr/bin/env bash
# BSV Skills Bootstrap (Stage 1 - Public)
#
# Contains no secrets. Authenticates with GitHub, clones the private
# BasisSetVentures/claude-plugins repo, then runs the private setup script.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/BasisSetVentures/bsv-skills-setup/main/bootstrap.sh | bash
#
# Environment variables:
#   BSV_SETUP_REPO   Override source repo (default: BasisSetVentures/claude-plugins)
#   BSV_PLUGINS_REF  Override branch/tag/SHA (default: main)

set -euo pipefail

REPO="${BSV_SETUP_REPO:-BasisSetVentures/claude-plugins}"
REF="${BSV_PLUGINS_REF:-main}"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; }

echo "========================================="
echo "  BSV Skills Bootstrap"
echo "  repo: $REPO  ref: $REF"
echo "========================================="
echo ""

# --- Prerequisites ---
info "Checking prerequisites..."
missing=()
command -v gh &>/dev/null || missing+=("gh (brew install gh)")
command -v python3 &>/dev/null || missing+=("python3 (brew install python)")
command -v uv &>/dev/null || missing+=("uv (brew install uv)")
command -v git &>/dev/null || missing+=("git")

if [ ${#missing[@]} -gt 0 ]; then
    fail "Missing required tools:"
    for tool in "${missing[@]}"; do echo "  - $tool"; done
    exit 1
fi
ok "Prerequisites installed"

# --- GitHub Auth ---
info "Checking GitHub authentication..."
if ! gh auth status &>/dev/null; then
    echo ""
    echo "GitHub authentication required. Starting login..."
    gh auth login
fi

if ! gh auth status &>/dev/null; then
    fail "GitHub authentication failed. Run 'gh auth login' manually."
    exit 1
fi
ok "GitHub authenticated"

# --- Repo Access ---
info "Checking access to $REPO..."
if ! gh api "repos/$REPO" --jq '.full_name' &>/dev/null; then
    fail "Cannot access $REPO. Request access from admin."
    exit 1
fi
ok "Repository access confirmed"

# --- Authenticated clone via gh CLI ---
info "Downloading setup from $REPO@$REF..."

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# Use gh repo clone (authenticated via gh session, works for private repos).
if gh repo clone "$REPO" "$WORK_DIR/claude-plugins" -- --branch "$REF" --depth 1 --quiet 2>/dev/null; then
    ok "Setup downloaded ($REF)"
else
    # Fall back to full gh clone + checkout for SHA refs.
    info "Fetching by SHA..."
    rm -rf "$WORK_DIR/claude-plugins"
    if gh repo clone "$REPO" "$WORK_DIR/claude-plugins" -- --quiet 2>/dev/null; then
        git -C "$WORK_DIR/claude-plugins" checkout "$REF" --quiet 2>/dev/null || {
            fail "Could not checkout ref: $REF"
            exit 1
        }
        ok "Setup downloaded (${REF:0:7})"
    else
        fail "Could not clone $REPO. Check gh auth and repo access."
        exit 1
    fi
fi

if [ ! -f "$WORK_DIR/claude-plugins/scripts/bsv-setup.sh" ]; then
    fail "Setup script not found at ref $REF. Contact admin."
    exit 1
fi

# --- Run Stage 2 ---
echo ""
bash "$WORK_DIR/claude-plugins/scripts/bsv-setup.sh" "$@"
