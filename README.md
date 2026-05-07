# BSV Skills Setup

Public bootstrap entrypoint for installing and updating BSV Claude Code and Codex skills.

This repository intentionally contains no secrets. The bootstrap script authenticates the user with GitHub, verifies access to the private `BasisSetVentures/claude-plugins` repository, downloads the private setup script, and runs it locally.

## Run

```bash
curl -fsSL https://raw.githubusercontent.com/BasisSetVentures/bsv-skills-setup/main/bootstrap.sh | bash
```

Pass setup flags through `bash -s --`:

```bash
curl -fsSL https://raw.githubusercontent.com/BasisSetVentures/bsv-skills-setup/main/bootstrap.sh | bash -s -- --status
curl -fsSL https://raw.githubusercontent.com/BasisSetVentures/bsv-skills-setup/main/bootstrap.sh | bash -s -- --yes
```

## Requirements

- `gh`
- `git`
- `python3`
- `uv`
- GitHub access to `BasisSetVentures/claude-plugins`

On macOS:

```bash
brew install gh git python uv
gh auth login
```

## Optional Overrides

```bash
export BSV_SETUP_REPO=BasisSetVentures/claude-plugins
export BSV_PLUGINS_REF=main
```

Use `BSV_PLUGINS_REF` to test a branch, tag, or SHA before it is merged:

```bash
export BSV_PLUGINS_REF=my-branch
curl -fsSL https://raw.githubusercontent.com/BasisSetVentures/bsv-skills-setup/main/bootstrap.sh | bash
```

## Security

This public bootstrap script does not contain credentials. Secret and private setup data must come from authenticated private systems after the user has proved access.
