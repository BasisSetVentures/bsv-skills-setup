# BSV Skills Setup

Public bootstrap entrypoint for installing and updating BSV Claude Code and Codex skills.

This repository intentionally contains no secrets. The bootstrap script authenticates the user with GitHub, verifies access to the private `BasisSetVentures/claude-plugins` repository, downloads the private setup script, and runs it locally.

## Run

```bash
curl -fsSL https://raw.githubusercontent.com/BasisSetVentures/bsv-skills-setup/main/bootstrap.sh | bash -s -- --yes
```

Pass setup flags through `bash -s --`:

```bash
curl -fsSL https://raw.githubusercontent.com/BasisSetVentures/bsv-skills-setup/main/bootstrap.sh | bash -s -- --status
curl -fsSL https://raw.githubusercontent.com/BasisSetVentures/bsv-skills-setup/main/bootstrap.sh | bash -s -- --yes
curl -fsSL https://raw.githubusercontent.com/BasisSetVentures/bsv-skills-setup/main/bootstrap.sh | bash -s -- --yes --include-plugin pascal-linear
```

After plugin installation, run `pascal login`. With `--include-plugin pascal-linear`,
setup also prints optional Linear Personal API key instructions.
The downloaded setup also removes retired BSV laptop hooks and credentials on
every run, including `--status`, while preserving unrelated hooks and settings.

## Requirements

- Claude Code CLI or Codex CLI
- GitHub access to `BasisSetVentures/claude-plugins`

The bootstrap tries to install missing supported tools before stopping. On macOS it can install:

- Homebrew
- `gh`
- `git`
- `python3`
- Claude Code CLI using `curl -fsSL https://claude.ai/install.sh | bash`
- Codex CLI using `brew install --cask codex`, with `npm i -g @openai/codex` fallback

If GitHub auth is missing, the script launches:

```bash
gh auth login --hostname github.com --git-protocol https --web --scopes repo
```

If one of Claude Code CLI or Codex CLI is missing and you decline installation, setup continues for the available client. If neither client is available, setup stops with an error.

## Optional Overrides

```bash
export BSV_SETUP_REPO=BasisSetVentures/claude-plugins
export BSV_PLUGINS_REF=main
```

Use `BSV_PLUGINS_REF` to test a branch, tag, or SHA before it is merged:

```bash
export BSV_PLUGINS_REF=my-branch
curl -fsSL https://raw.githubusercontent.com/BasisSetVentures/bsv-skills-setup/main/bootstrap.sh | bash -s -- --yes
```

## Security

This public bootstrap script does not contain credentials. Secret and private setup data must come from authenticated private systems after the user has proved access.
