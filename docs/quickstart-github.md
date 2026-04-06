# Quickstart: GitHub Actions

Get the generic-cicd pipeline running on your GitHub repo in 3 steps.

## Steps

### 1. Copy the caller workflow

```bash
# In your repo:
mkdir -p .github/workflows
curl -o .github/workflows/pr.yml \
  https://raw.githubusercontent.com/yashrajsapra/generic-cicd/main/github/example-caller.yml
```

Or copy `github/example-caller.yml` from this repo to `.github/workflows/pr.yml`.

### 2. Add the API key secret

Go to your repo on GitHub:
**Settings → Secrets and variables → Actions → New repository secret**

| Name | Value |
|------|-------|
| `ANTHROPIC_API_KEY` | Your Anthropic API key |

The code-review stage is silently skipped if this secret is absent.

### 3. Open a PR

Push a branch and open a pull request. The pipeline triggers automatically on
`opened`, `synchronize`, and `reopened` events.

Stages run in this order: **lint + security-scan** (parallel) → **test** → **build** → **code-review**

## Optional: Customize behavior

Add `.cicd/config.yml` to your repo to override defaults.
See [docs/customization.md](customization.md) for the full reference.

## Troubleshooting

**Code review stage is skipped**
The `ANTHROPIC_API_KEY` secret is missing or empty. Add it under repo Secrets.

**`yamllint` errors in the workflow file**
Ensure you copied the file exactly. Common issue: tabs vs spaces (YAML requires spaces).

**`scripts/*.sh: not found`**
The caller workflow must reference this repo correctly. Check the `uses:` line points
to `yashrajsapra/generic-cicd/.github/workflows/cicd-pipeline.yml@main`.

**Lint/test/build stage fails immediately**
No stack was detected. Add a `package.json`, `requirements.txt`, `go.mod`, or `.csproj`
to your repo root, or set `stages.lint.command` in `.cicd/config.yml`.
