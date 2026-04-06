# generic-cicd

Reusable CI/CD pipeline for GitHub Actions and Bitbucket Pipelines.
Auto-detects stack, runs lint/test/build/security-scan/code-review on every PR.
Adopt in any repo by copying a single ~15-line file.

## Stage Dependency Graph

```
+--------+   +---------------+
|  lint  |   | security-scan |   <- parallel
+---+----+   +------+--------+
    +----------+    |
               v    v
             +------+
             |  test  |
             +--+-----+
                |
             +--+------+
             |  build  |
             +---------+
                |
        +-------+--------+
        |  code-review   |   <- non-blocking by default
        +----------------+
                |
      +---------+---------+
      |  deploy-preview   |   <- optional / manual trigger
      +-------------------+
```

## Quick Start

| Step | GitHub Actions | Bitbucket Pipelines |
|------|----------------|---------------------|
| 1 | Copy `github/example-caller.yml` to `.github/workflows/pr.yml` | Copy `bitbucket/example-caller.yml` to `bitbucket-pipelines.yml` |
| 2 | Add `ANTHROPIC_API_KEY` repo secret | Add `ANTHROPIC_API_KEY`, `BB_USER`, `BB_TOKEN` repo variables |
| 3 | Open a PR — pipeline runs automatically | Open a PR — pipeline runs automatically |

Full guides: [GitHub quickstart](docs/quickstart-github.md) | [Bitbucket quickstart](docs/quickstart-bitbucket.md)

## Required Secrets / Variables

| Name | GitHub | Bitbucket | Purpose |
|------|--------|-----------|---------|
| `ANTHROPIC_API_KEY` | repo secret | repo variable | AI code review (skipped if absent) |
| `GITHUB_TOKEN` | auto-provided | — | `gh` CLI for PR diffs and comments |
| `BB_USER` | — | repo variable | Atlassian email for Bitbucket API |
| `BB_TOKEN` | — | repo variable | App password (`pullrequest:write` scope) |

## Docs

- [Quickstart: GitHub](docs/quickstart-github.md)
- [Quickstart: Bitbucket](docs/quickstart-bitbucket.md)
- [Customization reference](docs/customization.md)
- [Adding custom stages](docs/adding-stages.md)
- [Design notes](design.md)

## Repo Structure

```
generic-cicd/
├── github/
│   ├── cicd-pipeline.yml        # Reusable workflow (workflow_call)
│   └── example-caller.yml       # Copy to .github/workflows/pr.yml
├── bitbucket/
│   ├── pipeline-template.yml    # Shared step definitions
│   └── example-caller.yml       # Copy to bitbucket-pipelines.yml
├── scripts/                     # Provider-agnostic bash scripts
│   ├── detect-provider.sh
│   ├── detect-stack.sh
│   ├── load-config.sh
│   ├── run-stage.sh
│   ├── pr-diff.sh
│   ├── pr-comment.sh
│   ├── security-scan.sh
│   └── code-review.sh
├── config/defaults.yml          # Pipeline defaults
├── .cicd/config.yml.example     # Annotated config template
└── docs/                        # Guides
```
