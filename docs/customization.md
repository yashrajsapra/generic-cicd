# Customization Reference

Create `.cicd/config.yml` in your repo to customize the pipeline.
All keys are optional — the pipeline works with zero configuration.
See `.cicd/config.yml.example` for an annotated template.

## Configuration Keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `stages.lint.enabled` | bool | `true` | Run the lint stage |
| `stages.lint.command` | string | auto | Override lint command (default: auto-detected per stack) |
| `stages.test.enabled` | bool | `true` | Run the test stage |
| `stages.test.command` | string | auto | Override test command |
| `stages.build.enabled` | bool | `true` | Run the build stage |
| `stages.build.command` | string | auto | Override build command |
| `stages.security-scan.enabled` | bool | `true` | Run gitleaks + dependency audit |
| `stages.code-review.enabled` | bool | `true` | Run AI code review via Claude |
| `stages.code-review.blocking` | bool | `false` | Fail the PR on BLOCKER/HIGH severity findings |
| `stages.deploy-preview.enabled` | bool | `false` | Enable deploy-preview stage |
| `stages.deploy-preview.command` | string | `""` | Command to run for deploy preview (required to activate) |

### Auto-detected commands per stack

| Stack | lint | test | build |
|-------|------|------|-------|
| Node.js | `npm run lint` | `npm test` | `npm run build` |
| Python | `flake8 .` | `pytest` | `python -m build` |
| Go | `golangci-lint run` | `go test ./...` | `go build ./...` |
| .NET | `dotnet format --verify-no-changes` | `dotnet test` | `dotnet build` |

## Hooks

Run custom scripts before or after any stage by adding hook entries to `.cicd/config.yml`:

```yaml
hooks:
  lint.pre:  ".cicd/hooks/lint.pre.sh"
  lint.post: ".cicd/hooks/lint.post.sh"
  test.pre:  ".cicd/hooks/test.pre.sh"
```

Create the referenced shell scripts in your repo. They are sourced by `scripts/run-stage.sh`
before (`pre`) or after (`post`) the main stage command. If the script does not exist
the hook is silently skipped.

**Example** — install extra tools before lint:

```bash
# .cicd/hooks/lint.pre.sh
pip install flake8-bugbear flake8-comprehensions
```

## Environment Variables

These variables are respected by the pipeline scripts:

| Variable | Set by | Description |
|----------|--------|-------------|
| `ANTHROPIC_API_KEY` | repo secret/var | Enables code-review stage |
| `PR_NUMBER` | workflow input | Pull request number (auto-set) |
| `CONFIG_PATH` | workflow input | Path to config file (default: `.cicd/config.yml`) |
| `BLOCKING` | workflow input | `true` = fail on BLOCKER/HIGH review findings |
| `BB_USER` | repo var (Bitbucket) | Atlassian email for API auth |
| `BB_TOKEN` | repo var (Bitbucket) | App password for API auth |
| `BITBUCKET_PR_ID` | Bitbucket auto | PR number injected by Bitbucket Pipelines |
| `GITHUB_TOKEN` | GitHub auto | Used by `gh` CLI on GitHub Actions |
