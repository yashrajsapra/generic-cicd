# Design — Generic CI/CD Pipeline

## Problem
- Each repo duplicates CI/CD logic — inconsistent, hard to maintain
- No unified code review across GitHub and Bitbucket projects
- Adding a new check requires touching workflows in every repo

## Solution
A single repo (`yashrajsapra/generic-cicd`) hosts reusable pipeline definitions for both GitHub Actions and Bitbucket Pipelines. Core logic lives in provider-agnostic bash scripts. Provider-specific trigger files (`github/cicd-pipeline.yml`, `bitbucket/pipeline-template.yml`) call the same scripts. Any repo adopts by copying a ≤ 25-line starter file.

---

## Repo Structure

```
generic-cicd/
├── github/
│   ├── cicd-pipeline.yml        # Reusable workflow (workflow_call trigger)
│   └── example-caller.yml       # Copy to .github/workflows/pr.yml in target repos
│
├── bitbucket/
│   ├── pipeline-template.yml    # Shared pipeline template (Bitbucket import)
│   └── example-caller.yml       # Copy to bitbucket-pipelines.yml in target repos
│
├── scripts/
│   ├── detect-provider.sh       # Outputs: github | bitbucket
│   ├── detect-stack.sh          # Outputs: node | python | go | dotnet | unknown
│   ├── load-config.sh           # Merges .cicd/config.yml over config/defaults.yml
│   ├── run-stage.sh             # Runs: {stage}.pre → command → {stage}.post
│   ├── pr-diff.sh               # Fetches PR diff (provider-agnostic)
│   ├── pr-comment.sh            # Posts PR comment (provider-agnostic)
│   ├── security-scan.sh         # gitleaks + stack dependency audit
│   └── code-review.sh           # claude -p gstack-review → pr-comment.sh
│
├── config/
│   └── defaults.yml             # Default values for all stages
│
├── docs/
│   ├── quickstart-github.md
│   ├── quickstart-bitbucket.md
│   ├── customization.md         # Full .cicd/config.yml reference
│   └── adding-stages.md         # Extension guide
│
├── .cicd/
│   └── config.yml.example       # Annotated example for calling repos
│
└── README.md
```

---

## Provider Detection

```bash
# scripts/detect-provider.sh
if [ -n "$GITHUB_ACTIONS" ]; then echo "github"
elif [ -n "$BITBUCKET_BUILD_NUMBER" ]; then echo "bitbucket"
else echo "unknown"; fi
```

---

## PR Abstraction Layer

### `pr-diff.sh`
```bash
PROVIDER=$(./scripts/detect-provider.sh)
if [ "$PROVIDER" = "github" ]; then
  gh pr diff "$PR_NUMBER"
elif [ "$PROVIDER" = "bitbucket" ]; then
  curl -sf -u "$BB_USER:$BB_TOKEN" \
    "https://api.bitbucket.org/2.0/repositories/$BB_REPO_FULL_NAME/pullrequests/$PR_NUMBER/diff"
fi
```

### `pr-comment.sh <body-file>`
```bash
PROVIDER=$(./scripts/detect-provider.sh)
if [ "$PROVIDER" = "github" ]; then
  gh pr comment "$PR_NUMBER" --body-file "$1"
elif [ "$PROVIDER" = "bitbucket" ]; then
  BODY=$(cat "$1")
  curl -sf -X POST -u "$BB_USER:$BB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\":{\"raw\":\"$BODY\"}}" \
    "https://api.bitbucket.org/2.0/repositories/$BB_REPO_FULL_NAME/pullrequests/$PR_NUMBER/comments"
fi
```

---

## Config Schema (`.cicd/config.yml`)

```yaml
stages:
  lint:
    enabled: true
    command: ""           # auto-detected if empty
  test:
    enabled: true
    command: ""
  build:
    enabled: true
    command: ""
  security-scan:
    enabled: true
  code-review:
    enabled: true
    blocking: false       # true = fail PR on flagged issues
    model: "claude-sonnet-4-6"
  deploy-preview:
    enabled: false
    command: ""

hooks:
  lint.pre:  ".cicd/hooks/lint.pre.sh"
  lint.post: ".cicd/hooks/lint.post.sh"
  # pattern: {stage}.{pre|post}

env:
  NODE_ENV: "test"
```

---

## GitHub Workflow Structure (`github/cicd-pipeline.yml`)

```yaml
on:
  workflow_call:
    inputs:
      pr-number: { type: number, required: true }
      config-path: { type: string, default: '.cicd/config.yml' }
    secrets:
      ANTHROPIC_API_KEY: { required: false }
      BB_USER: { required: false }   # not used on GitHub but kept for parity
      BB_TOKEN: { required: false }

jobs:
  lint:      { runs-on: ubuntu-latest, ... }
  security:  { runs-on: ubuntu-latest, needs: [] }  # parallel with lint
  test:      { needs: [lint] }
  build:     { needs: [test] }
  review:    { needs: [build], continue-on-error: true }
  preview:   { needs: [review], if: inputs.deploy-preview-enabled }
```

---

## Bitbucket Pipeline Structure (`bitbucket/pipeline-template.yml`)

```yaml
definitions:
  steps:
    - step: &lint
        name: Lint
        script:
          - scripts/run-stage.sh lint "$(scripts/load-config.sh lint.command)"
    - step: &security
        name: Security Scan
        script: [ scripts/security-scan.sh ]
    - step: &test
        name: Test
        script: [ scripts/run-stage.sh test "..." ]
    - step: &build
        name: Build
        script: [ scripts/run-stage.sh build "..." ]
    - step: &review
        name: Code Review
        script: [ scripts/code-review.sh ]

pull-requests:
  '**':
    - parallel:
        - step: *lint
        - step: *security
    - step: *test
    - step: *build
    - step: *review
```

---

## Stage Dependency Graph (both providers)

```
   ┌──────┐   ┌──────────────┐
   │ lint │   │security-scan │  ← parallel
   └──┬───┘   └──────┬───────┘
      └───────┬───────┘
              ▼
           ┌──────┐
           │ test │
           └──┬───┘
              ▼
           ┌───────┐
           │ build │
           └──┬────┘
              ▼
        ┌──────────────┐
        │ code-review  │  ← non-blocking default
        └──────┬───────┘
               ▼
      ┌─────────────────┐
      │ deploy-preview  │  ← optional
      └─────────────────┘
```

---

## Required Secrets per Provider

| Secret | GitHub | Bitbucket | Purpose |
|--------|--------|-----------|---------|
| `ANTHROPIC_API_KEY` | repo secret | env var | code-review stage |
| `GITHUB_TOKEN` | auto | — | gh CLI (GitHub only) |
| `BB_USER` | — | repo var | Bitbucket API auth |
| `BB_TOKEN` | — | repo var | Bitbucket API auth |

---

## Out of Scope (v1)
- Azure DevOps
- Matrix / multi-OS
- Auto repo registration
