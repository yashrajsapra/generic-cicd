# Generic CI/CD Pipeline — Requirements

## Goal
Build a reusable, extensible CI/CD pipeline that runs on any PR across any repo, supporting **both GitHub Actions and Bitbucket Pipelines**. Per-repo customization via `.cicd/config.yml`. Automated code review via `gstack-review` skill using `claude -p`.

## Functional Requirements

### FR1 — Dual Provider Support
- **GitHub**: Reusable workflow (`workflow_call`) — hosted at `yashrajsapra/generic-cicd`
- **Bitbucket**: Shared pipeline template — consumed via `import:` in `bitbucket-pipelines.yml`
- Core scripts are provider-agnostic bash; only the trigger layer is provider-specific
- Provider auto-detected at runtime via `$GITHUB_ACTIONS` / `$BITBUCKET_BUILD_NUMBER` env vars

### FR2 — Runs on All PRs
- GitHub: triggers on `pull_request` events (opened, synchronize, reopened)
- Bitbucket: triggers on `pull-requests: '**'` pattern

### FR3 — Customization Per Repo
- `.cicd/config.yml` in the calling repo overrides defaults
- Enable/disable any stage
- Override commands per stage
- Set env vars per stage
- Hooks: `.cicd/hooks/{stage}.pre.sh` / `{stage}.post.sh`
- Hooks are optional — pipeline runs without them

### FR4 — Pipeline Stages (same for both providers)
1. **lint** — auto-detected or configured linter
2. **test** — auto-detected or configured test runner
3. **build** — auto-detected or configured build command
4. **security-scan** — gitleaks (secrets) + stack-appropriate dependency audit
5. **code-review** — `claude -p --skill gstack-review` on PR diff → posts as PR comment
6. **deploy-preview** — optional, user-configured command

### FR5 — Provider Abstraction Scripts
- `scripts/detect-provider.sh` → outputs `github | bitbucket`
- `scripts/pr-diff.sh` → fetches PR diff regardless of provider
- `scripts/pr-comment.sh` → posts PR comment regardless of provider
  - GitHub: `gh pr comment $PR_NUMBER --body-file $1`
  - Bitbucket: Bitbucket REST API (`curl` with `$BB_TOKEN`)

### FR6 — Code Review Integration
- Non-blocking by default (`blocking: false`)
- Configurable to fail the check (`blocking: true`)
- Gracefully skips if `ANTHROPIC_API_KEY` not set (logs a warning)
- Review posted as PR comment with structured output from `gstack-review`

### FR7 — Extension Interface
- `scripts/run-stage.sh <stage> <command>` wraps any stage with hooks
- Adding a stage = copy job template + add to both provider workflow files
- `docs/adding-stages.md` documents exact steps

## Non-Functional Requirements
- Zero-config default (works without `.cicd/config.yml`)
- Caller boilerplate: ≤ 20 lines for GitHub, ≤ 25 lines for Bitbucket
- Scripts are POSIX-compatible bash (no bashisms beyond `local`)

## Out of Scope (v1)
- Azure DevOps
- Matrix / multi-OS builds
- Auto-registration of repos
