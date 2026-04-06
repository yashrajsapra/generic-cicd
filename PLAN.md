# Generic CI/CD Pipeline — Implementation Plan

> Reusable CI/CD pipeline for GitHub Actions + Bitbucket Pipelines. Provider-agnostic core scripts. Per-repo `.cicd/config.yml` customization. Hook system. Automated code review via `claude -p --skill gstack-review`.

---

## Tasks

### Phase 1: Foundation — Scripts + Provider Abstraction

#### Task 1.1: Repo skeleton + provider detection
- **Change:** Create the directory structure. Create `scripts/detect-provider.sh` (outputs `github|bitbucket` based on `$GITHUB_ACTIONS` / `$BITBUCKET_BUILD_NUMBER`). Create `scripts/detect-stack.sh` (outputs `node|python|go|dotnet|unknown` by probing `package.json`, `requirements.txt`, `go.mod`, `*.csproj`). Add `.gitignore` (include `CLAUDE.md`, `.env`). Add base `README.md`.
- **Files:** `scripts/detect-provider.sh`, `scripts/detect-stack.sh`, `.gitignore`, `README.md`
- **Done when:** `detect-provider.sh` outputs `github` when `GITHUB_ACTIONS=true` is set; outputs `bitbucket` when `BITBUCKET_BUILD_NUMBER=1` is set; `detect-stack.sh` outputs `node` when `package.json` exists in cwd
- **Blockers:** Scripts must be `chmod +x` and POSIX-compatible bash

#### Task 1.2: Config loader
- **Change:** Create `config/defaults.yml` with all stage defaults (enabled/disabled, empty commands, `blocking: false` for code-review). Create `scripts/load-config.sh` that deep-merges `.cicd/config.yml` (caller repo) over `config/defaults.yml` and outputs the resolved value for a given key (e.g. `load-config.sh stages.lint.command`). Uses Python `yaml` as fallback if `yq` is unavailable.
- **Files:** `config/defaults.yml`, `scripts/load-config.sh`
- **Done when:** `load-config.sh stages.lint.enabled` returns `true` with no `.cicd/config.yml`; returns overridden value when `.cicd/config.yml` sets it; handles missing config file gracefully

#### Task 1.3: Stage runner + PR abstraction layer
- **Change:** Create `scripts/run-stage.sh <stage> <command>` (sources `{stage}.pre.sh` if exists → runs command → sources `{stage}.post.sh`; exit code mirrors command). Create `scripts/pr-diff.sh` (GitHub: `gh pr diff $PR_NUMBER`; Bitbucket: Bitbucket REST API via curl with `$BB_USER:$BB_TOKEN`). Create `scripts/pr-comment.sh <body-file>` (GitHub: `gh pr comment`; Bitbucket: POST to PR comments API).
- **Files:** `scripts/run-stage.sh`, `scripts/pr-diff.sh`, `scripts/pr-comment.sh`
- **Done when:** `run-stage.sh test "echo ok"` runs hook then command; missing hook files are silently skipped; `pr-diff.sh` and `pr-comment.sh` branch correctly on `detect-provider.sh` output

#### VERIFY: Phase 1
- Set `GITHUB_ACTIONS=true`; run `detect-provider.sh` → must output `github`
- Create temp dir with `package.json`; run `detect-stack.sh` → must output `node`
- Run `load-config.sh` with and without `.cicd/config.yml` → verify defaults and overrides
- Run `run-stage.sh` with pre/post hooks present and absent
- **Report:** All scripts exit 0, provider/stack detection correct, config merge works

---

### Phase 2: Provider Workflow Files

#### Task 2.1: GitHub reusable workflow
- **Change:** Create `github/cicd-pipeline.yml` — reusable workflow (`on: workflow_call`) with inputs (`pr-number`, `config-path`) and secrets (`ANTHROPIC_API_KEY`). Jobs: `lint`, `security-scan` (parallel), `test` (needs lint), `build` (needs test), `code-review` (needs build, `continue-on-error: true`), `deploy-preview` (needs code-review, conditional on config). Each job: checks out caller repo, runs the corresponding script. Create `github/example-caller.yml` — ≤ 20-line template for any GitHub repo to copy into `.github/workflows/pr.yml`.
- **Files:** `github/cicd-pipeline.yml`, `github/example-caller.yml`
- **Done when:** `yamllint github/cicd-pipeline.yml` passes; all 6 job stubs present with correct `needs` ordering; `example-caller.yml` is ≤ 20 lines and references `cicd-pipeline.yml` via `workflow_call`

#### Task 2.2: Bitbucket pipeline template
- **Change:** Create `bitbucket/pipeline-template.yml` — shared pipeline using `definitions.steps` anchors for each stage. Pull-requests section triggers on `'**'` (all branches). Parallel group: `lint` + `security-scan`. Sequential: `test`, `build`, `code-review`, optional `deploy-preview`. Create `bitbucket/example-caller.yml` — ≤ 25-line template to copy as `bitbucket-pipelines.yml` in target repos (uses `import:` or inline step references).
- **Files:** `bitbucket/pipeline-template.yml`, `bitbucket/example-caller.yml`
- **Done when:** `yamllint bitbucket/pipeline-template.yml` passes; all stage anchors defined; pull-requests trigger uses `'**'`; `example-caller.yml` ≤ 25 lines

#### VERIFY: Phase 2
- `yamllint` both workflow files
- Verify GitHub workflow has correct `workflow_call` trigger and all 6 jobs
- Verify Bitbucket template has `pull-requests: '**':` section with parallel group
- Verify `example-caller.yml` files are ≤ line count limits
- **Report:** Both files lint clean, structure matches design.md

---

### Phase 3: Core CI Stages

#### Task 3.1: Lint, Test, Build stages
- **Change:** Implement auto-command resolution in `scripts/detect-stack.sh` — add `--command <stage>` flag: `detect-stack.sh --command lint` outputs the default command for the detected stack (Node→`npm run lint`, Python→`flake8 .`, Go→`golangci-lint run`, Dotnet→`dotnet format --verify-no-changes`; same pattern for test and build). Wire this into both `github/cicd-pipeline.yml` and `bitbucket/pipeline-template.yml` jobs: resolved command = config override OR `detect-stack.sh --command <stage>`.
- **Files:** `scripts/detect-stack.sh` (extend), `github/cicd-pipeline.yml` (lint/test/build jobs), `bitbucket/pipeline-template.yml` (lint/test/build steps)
- **Done when:** Running `detect-stack.sh --command test` in a Python project outputs `pytest`; both workflow files use `run-stage.sh` with resolved command; config override takes precedence

#### Task 3.2: Security scan stage
- **Change:** Create `scripts/security-scan.sh`: (1) run `gitleaks detect --source . --no-banner` for secret scanning, (2) run stack-appropriate dependency audit (`npm audit --audit-level high` / `pip-audit` / `go mod verify`). Write findings to `$GITHUB_STEP_SUMMARY` (GitHub) or stdout (Bitbucket). Wire into both workflow files as a parallel job/step alongside lint.
- **Files:** `scripts/security-scan.sh`, `github/cicd-pipeline.yml` (security-scan job), `bitbucket/pipeline-template.yml` (security-scan step)
- **Done when:** Script handles missing tools gracefully (warn + skip); gitleaks runs; audit command is stack-appropriate; job/step is parallel with lint in both providers

#### VERIFY: Phase 3
- Run `detect-stack.sh --command test` from a temp Python dir → must output `pytest`
- Run `security-scan.sh` in the repo itself → must complete without crash
- Review both workflow YAML files — verify lint + security-scan are parallel, test→build are sequential
- **Report:** All commands resolve correctly, security scan runs, workflow ordering correct

---

### Phase 4: Code Review Stage

#### Task 4.1: Code review script
- **Change:** Create `scripts/code-review.sh`: (1) call `pr-diff.sh` → `/tmp/pr.diff`, (2) check diff size — truncate to 8000 chars with a note if over limit, (3) run `claude -p --skill gstack-review` with the diff piped as stdin (fallback: inline system prompt if skill not available), (4) save output → `/tmp/review.md`, (5) call `pr-comment.sh /tmp/review.md`, (6) if `BLOCKING=true` and review contains `BLOCKER` or severity `HIGH`, exit 1. Handle missing `ANTHROPIC_API_KEY` with a warning and skip.
- **Files:** `scripts/code-review.sh`
- **Done when:** Script produces a `/tmp/review.md` file when run with a valid diff on stdin; `pr-comment.sh` is called; blocking mode exits 1 when BLOCKER present; missing API key prints warning and exits 0

#### Task 4.2: Wire code review into both providers
- **Change:** GitHub `cicd-pipeline.yml` code-review job: add step to install claude CLI (`npm install -g @anthropic-ai/claude-code`), set `ANTHROPIC_API_KEY` from secret, set `PR_NUMBER` and `BLOCKING` env vars, run `scripts/code-review.sh`. Set `continue-on-error` based on `blocking` config. Bitbucket `pipeline-template.yml` code-review step: same install + env var pattern using Bitbucket repository variables (`$ANTHROPIC_API_KEY`, `$BB_USER`, `$BB_TOKEN`).
- **Files:** `github/cicd-pipeline.yml` (code-review job), `bitbucket/pipeline-template.yml` (code-review step)
- **Done when:** Both workflow files have claude CLI install step; secrets/vars are wired correctly; `continue-on-error` / `allow_failure` set per blocking config

#### VERIFY: Phase 4
- Dry-run `code-review.sh` with a sample diff file and unset `ANTHROPIC_API_KEY` → must warn and exit 0
- Inspect both workflow files — verify code-review runs after build, claude install present, secrets wired
- Test blocking mode: create a diff mentioning "hardcoded password", run with `BLOCKING=true` → should exit 1 (or verify logic path)
- **Report:** Graceful skip verified, workflow structure correct, blocking logic works

---

### Phase 5: Extensibility + Documentation

#### Task 5.1: Deploy-preview stage + hook finalization
- **Change:** Add optional `deploy-preview` stage to both workflow files — only runs when `deploy-preview.enabled: true` in config (GitHub: `if:` condition; Bitbucket: manual trigger or condition). Finalize `.cicd/config.yml.example` with all options annotated. Create `docs/adding-stages.md` with the exact copy-paste template for adding a new stage to both provider files.
- **Files:** `github/cicd-pipeline.yml`, `bitbucket/pipeline-template.yml`, `.cicd/config.yml.example`, `docs/adding-stages.md`
- **Done when:** deploy-preview is skipped by default in both providers; `.cicd/config.yml.example` covers all config keys with comments; `adding-stages.md` has a working template

#### Task 5.2: Caller templates + full docs
- **Change:** Polish both `example-caller.yml` files to final form. Create `docs/quickstart-github.md` (copy + one secret = running in 5 min). Create `docs/quickstart-bitbucket.md`. Create `docs/customization.md` (full config reference). Update `README.md` with badges, quickstart links, and stage dependency diagram.
- **Files:** `github/example-caller.yml`, `bitbucket/example-caller.yml`, `docs/quickstart-github.md`, `docs/quickstart-bitbucket.md`, `docs/customization.md`, `README.md`
- **Done when:** Both caller templates ≤ stated line limits; quickstart guides are < 1 page each; `customization.md` documents every config key with type, default, and example

#### VERIFY: Phase 5
- Count lines in both `example-caller.yml` files — must meet limits
- Read through `quickstart-github.md` — can a new user follow it in < 5 min?
- Validate README renders correctly (check markdown)
- **Report:** Line counts confirmed, docs reviewed, README complete

---

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| `claude` CLI not on GitHub/Bitbucket runners | High | Install in job step; cache with actions/cache |
| `ANTHROPIC_API_KEY` not set | Med | Graceful skip with clear warning |
| `yq` unavailable for config merge | Med | Python `yaml` fallback in `load-config.sh` |
| Bitbucket API auth not set (`BB_USER`/`BB_TOKEN`) | Med | Skip PR comment with warning, don't fail build |
| PR diff exceeds claude context limit | Med | Truncate to 8000 chars with note in review |
| `gitleaks` not on runner | Low | `apt-get install gitleaks` or skip with warning |

## Notes
- Each task = one git commit
- VERIFY tasks are checkpoints — push branch and STOP for PM review
- Base branch: `main`
- Feature branch: `feat/generic-cicd-pipeline`
- Scripts must be POSIX bash (run on Linux GitHub/Bitbucket runners)
