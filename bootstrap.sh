#!/usr/bin/env bash
# BSV Skills Bootstrap (Stage 1 - Public)
#
# Contains no secrets. Authenticates with GitHub, clones the private
# BasisSetVentures/claude-plugins repo, then runs the private setup script.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/BasisSetVentures/bsv-skills-setup/main/bootstrap.sh | bash -s -- --yes
#
# Environment variables:
#   BSV_SETUP_REPO   Override source repo (default: BasisSetVentures/claude-plugins)
#   BSV_PLUGINS_REF  Override branch/tag/SHA (default: main)

set -euo pipefail

REPO="${BSV_SETUP_REPO:-BasisSetVentures/claude-plugins}"
REF="${BSV_PLUGINS_REF:-main}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; }

AUTO_YES=false
for arg in "$@"; do
    case "$arg" in
        --yes|-y) AUTO_YES=true ;;
    esac
done

confirm() {
    local prompt="$1"
    if [ "$AUTO_YES" = true ]; then
        info "$prompt [auto-yes]"
        return 0
    fi
    local answer=""
    if [ -e /dev/tty ]; then
        if { echo -en "${YELLOW}$prompt [y/N]${NC} " > /dev/tty; } 2>/dev/null && { read -r answer < /dev/tty; } 2>/dev/null; then
            [[ "$answer" =~ ^[Yy] ]]
        else
            return 1
        fi
    else
        return 1
    fi
}

run_interactive() {
    if [ -e /dev/tty ]; then
        "$@" < /dev/tty
    else
        "$@"
    fi
}

download_and_run_bash() {
    local url="$1"
    local tmp_file status
    tmp_file=$(mktemp)
    status=0
    if curl -fsSL "$url" -o "$tmp_file"; then
        run_interactive bash "$tmp_file" || status=$?
    else
        status=$?
    fi
    rm -f "$tmp_file"
    return "$status"
}

command_exists() {
    command -v "$1" &>/dev/null
}

is_macos() {
    [ "$(uname -s 2>/dev/null || echo "")" = "Darwin" ]
}

install_homebrew_if_needed() {
    command_exists brew && return 0
    is_macos || return 1

    if confirm "Homebrew is missing. Install Homebrew?"; then
        info "Installing Homebrew..."
        if download_and_run_bash "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"; then
            if [ -x /opt/homebrew/bin/brew ]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            elif [ -x /usr/local/bin/brew ]; then
                eval "$(/usr/local/bin/brew shellenv)"
            fi
            command_exists brew && ok "Homebrew installed" && return 0
        fi
    fi
    return 1
}

brew_install_tool() {
    local tool="$1" package="$2"
    command_exists "$tool" && return 0
    command_exists brew || install_homebrew_if_needed || return 1

    if confirm "Install $tool with Homebrew?"; then
        info "Installing $tool..."
        run_interactive brew install "$package" && command_exists "$tool" && return 0
    fi
    return 1
}

install_claude_cli() {
    command_exists claude && return 0
    if confirm "Claude Code CLI is missing. Install it now?"; then
        info "Installing Claude Code CLI..."
        download_and_run_bash "https://claude.ai/install.sh"
        hash -r 2>/dev/null || true
        command_exists claude && return 0
    fi
    return 1
}

install_codex_cli() {
    command_exists codex && return 0
    if confirm "Codex CLI is missing. Install it now?"; then
        if command_exists brew || install_homebrew_if_needed; then
            info "Installing Codex CLI with Homebrew..."
            run_interactive brew install --cask codex && command_exists codex && return 0
        fi
        if command_exists npm || brew_install_tool npm node; then
            info "Installing Codex CLI with npm fallback..."
            run_interactive npm i -g @openai/codex
            hash -r 2>/dev/null || true
            command_exists codex && return 0
        fi
    fi
    return 1
}

echo "========================================="
echo "  BSV Skills Bootstrap"
echo "  repo: $REPO  ref: $REF"
echo "========================================="
echo ""

# --- Prerequisites ---
info "Checking prerequisites..."
command_exists git || brew_install_tool git git || true
command_exists gh || brew_install_tool gh gh || true
command_exists python3 || brew_install_tool python3 python || true

missing=()
for tool in git gh python3; do
    command_exists "$tool" || missing+=("$tool")
done

if [ ${#missing[@]} -gt 0 ]; then
    fail "Missing required tools after install attempts:"
    for tool in "${missing[@]}"; do echo "  - $tool"; done
    exit 1
fi
ok "Required prerequisites installed"

if ! command_exists claude; then
    install_claude_cli || info "Claude Code CLI skipped or unavailable"
fi
if ! command_exists codex; then
    install_codex_cli || info "Codex CLI skipped or unavailable"
fi
if ! command_exists claude && ! command_exists codex; then
    fail "Neither Claude Code CLI nor Codex CLI is available. Install at least one and rerun this command."
    exit 1
fi

# --- GitHub Auth ---
info "Checking GitHub authentication..."
if ! gh auth status -h github.com &>/dev/null; then
    echo ""
    echo "GitHub authentication required. Starting login..."
    run_interactive gh auth login --hostname github.com --git-protocol https --web --scopes repo
fi

if ! gh auth status -h github.com &>/dev/null; then
    fail "GitHub authentication failed. Run: gh auth login --hostname github.com --git-protocol https --web --scopes repo"
    exit 1
fi
ok "GitHub authenticated"

# --- Repo Access ---
info "Checking access to $REPO..."
if ! gh api "repos/$REPO" --jq '.full_name' &>/dev/null; then
    warn "Cannot access $REPO with current GitHub auth."
    if confirm "Refresh GitHub auth with private repo scope?"; then
        run_interactive gh auth refresh -h github.com -s repo || true
    fi
    if ! gh api "repos/$REPO" --jq '.full_name' &>/dev/null; then
        fail "Cannot access $REPO. Request access from admin or run: gh auth refresh -h github.com -s repo"
        exit 1
    fi
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
