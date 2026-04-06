# Adding a Custom Stage

This guide shows how to add a new stage (e.g. `e2e`) to both providers.

## 1. Add to GitHub Actions (`github/cicd-pipeline.yml`)

Add an input if needed, then add a new job under `jobs:`:

```yaml
# In on.workflow_call.inputs (optional):
      e2e-enabled:
        type: boolean
        default: false

# New job:
  e2e:
    name: E2E Tests
    runs-on: ubuntu-latest
    needs: [build]
    if: inputs.e2e-enabled == true
    steps:
      - uses: actions/checkout@v4
      - name: Run e2e stage
        env:
          PR_NUMBER: ${{ inputs.pr-number }}
        run: |
          chmod +x scripts/*.sh
          CMD=$(scripts/load-config.sh stages.e2e.command 2>/dev/null || echo "npm run e2e")
          scripts/run-stage.sh e2e "$CMD"
```

Sync the file to `.github/workflows/cicd-pipeline.yml`.

## 2. Add to Bitbucket (`bitbucket/pipeline-template.yml`)

Add a step anchor in `definitions.steps`, then reference it in `pull-requests`:

```yaml
# In definitions.steps:
    - step: &e2e
        name: E2E Tests
        image: ubuntu:22.04
        script:
          - chmod +x scripts/*.sh
          - CMD=$(scripts/load-config.sh stages.e2e.command 2>/dev/null || echo "npm run e2e")
          - scripts/run-stage.sh e2e "$CMD"

# In pull-requests.'**':
    - step: *e2e          # add after build
```

## 3. Add defaults to `config/defaults.yml`

```yaml
stages:
  e2e:
    enabled: true
    command: ""
```

## 4. Hook support via `run-stage.sh`

`run-stage.sh` automatically resolves `{stage}.pre` and `{stage}.post` hooks
from `.cicd/config.yml`. No changes needed -- hooks work for any stage name.

To use hooks for your new stage, add to `.cicd/config.yml`:

```yaml
hooks:
  e2e.pre:  ".cicd/hooks/e2e.pre.sh"
  e2e.post: ".cicd/hooks/e2e.post.sh"
```

Create the referenced `.sh` files in your calling repo.
