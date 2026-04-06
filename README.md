# generic-cicd

Reusable CI/CD pipeline for **GitHub Actions** and **Bitbucket Pipelines**.

Same core scripts, two provider trigger files. Per-repo `.cicd/config.yml` for customization. Automated code review via Claude.

## Quick Start

- **GitHub Actions** → see `docs/quickstart-github.md`
- **Bitbucket Pipelines** → see `docs/quickstart-bitbucket.md`

## Structure

```
scripts/          # POSIX bash scripts (run on Linux runners)
github/           # GitHub Actions workflow files
bitbucket/        # Bitbucket Pipelines template
config/           # Default configuration
docs/             # Guides and references
```

## Stages

| Stage | Parallel | Blocking |
|-------|----------|---------|
| lint | yes (with security-scan) | yes |
| security-scan | yes (with lint) | yes |
| test | no | yes |
| build | no | yes |
| code-review | no | configurable |
| deploy-preview | no | configurable |

## Configuration

Copy `.cicd/config.yml.example` to your repo as `.cicd/config.yml` and override any defaults.
