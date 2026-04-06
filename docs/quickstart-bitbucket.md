# Quickstart: Bitbucket Pipelines

Get the generic-cicd pipeline running on your Bitbucket repo in 3 steps.

## Steps

### 1. Copy the pipeline file

Copy `bitbucket/example-caller.yml` from this repo to `bitbucket-pipelines.yml`
in the root of your Bitbucket repository.

```bash
curl -o bitbucket-pipelines.yml \
  https://raw.githubusercontent.com/yashrajsapra/generic-cicd/main/bitbucket/example-caller.yml
```

### 2. Add repository variables

Go to your Bitbucket repo:
**Repository settings → Pipelines → Repository variables**

| Variable | Value | Notes |
|----------|-------|-------|
| `ANTHROPIC_API_KEY` | Your Anthropic API key | Code review; skipped if absent |
| `BB_USER` | Your Atlassian account email | PR commenting |
| `BB_TOKEN` | Bitbucket app password | Needs `pullrequest:write` scope |

To create an app password: **Personal settings → App passwords → Create app password**
Enable scopes: `Repositories: Read`, `Pull requests: Read`, `Pull requests: Write`.

### 3. Open a PR

Push a branch and open a pull request. The pipeline triggers automatically on
all branches (`'**'` pattern).

Stages: **lint + security-scan** (parallel) → **test** → **build** → **code-review**

## Optional: Customize behavior

Add `.cicd/config.yml` to your repo. See [docs/customization.md](customization.md).

## Troubleshooting

**Code review stage is skipped**
`ANTHROPIC_API_KEY` repo variable is missing or empty.

**PR comment not posted**
Check `BB_USER` (must be your email, not username) and `BB_TOKEN` (app password
with `pullrequest:write` scope). Verify `BITBUCKET_REPO_FULL_NAME` is set
(it is automatically in Bitbucket Pipelines).

**Pipeline doesn't trigger on PR**
Ensure Pipelines is enabled: **Repository settings → Pipelines → Enable Pipelines**.

**`scripts/*.sh: Permission denied`**
The `chmod +x scripts/*.sh` step should handle this. If cloning via HTTPS, ensure
`clone.depth: full` is not stripping executable bits (it shouldn't).
