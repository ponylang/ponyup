---
name: add-linux-bootstrap-platform
description: Load when adding a new Linux distro/version (e.g. Alpine 3.24, Ubuntu 26.04) — or both arches for an existing one — as a fully supported ponyup bootstrap-test target. Covers the bootstrap-tester Dockerfile, image build dispatch and tag discovery, CI workflow updates (tier 1 / tier 2), ponyup-init.sh detection, optional canonical-example promotion, and release notes.
disable-model-invocation: false
---

# Adding a New Linux Distro/Version as a ponyup Bootstrap-Test Target

## Scope

Use this skill when adding a Linux distro/version where ponyup needs to provide both `arm64` and `amd64` bootstrap testing (e.g. Alpine 3.24, Ubuntu 26.04 LTS). The procedure encodes the **multi-platform bootstrap-tester pattern** — a single `.ci-dockerfiles/<distro><version>-bootstrap-tester/` directory containing one `Dockerfile` and one `build-and-push.bash` that builds and publishes a multi-arch image (linux/amd64 + linux/arm64) under `ghcr.io/ponylang/ponyup-ci-<distro><version>-bootstrap-tester`.

**Out of scope:**
- macOS, Windows, any non-Linux platform.
- Adding a new OS or new CPU architecture.
- Removing platforms (different procedure, not covered here).
- Migrating older single-arch bootstrap-testers (e.g. `ubuntu22.04-bootstrap-tester`) to multi-arch — leave alone.

## Guiding facts

- **Purely additive.** Older supported versions stay until their own upstream EOL. Don't propose dropping anything as part of this work.
- **Both arches by default.** The multi-platform image builds linux/amd64 and linux/arm64 from one Dockerfile. Don't restrict arches without a concrete reason.
- **Multi-arch image gets a date-stamp tag** (`YYYYMMDD`).
- **Tier 1 vs tier 2 split is an ASK.** Skill describes the current convention as context (latest x86-64 of each distro family in `pr.yml` / tier 1; everything else, including all arm64, in `ponyup-tier2.yml` / tier 2) but does not enforce it. The user picks per arch.
- **SSL choice is an ASK.** Skill describes precedent (Alpine entries use `SSL=libressl` + `libressl-dev`; Ubuntu entries use `SSL=3.0.x` + `libssl-dev`) but does not pick. The user picks based on what the new distro packages and what we want to test against. The choice has **three downstream consistency requirements** — they must all agree, or the bootstrap test fails at link time deep in CI:
  1. The Dockerfile installs the matching dev package.
  2. The `SSL=` value in the bootstrap test job in `pr.yml`/`ponyup-tier2.yml` matches.
  3. `.ci-scripts/test-bootstrap.sh` passes the same value through to `ponyup`.
- **Mental model.** One multi-arch bootstrap-tester image is published to GHCR with a date-stamp tag. Two CI bootstrap jobs (one per arch) reference that one image by exact tag from their tier file — Docker pulls the matching arch on each runner. The job exercises `ponyup-init.sh` end-to-end against the new platform.
- **`ubuntu22.04-bootstrap-tester` is the legacy single-arch shape** and is intentionally not in the dispatch dropdown. Don't use it as a structural exemplar.

## File inventory

New files (a single bootstrap-tester directory with two files, plus a release note):
- `.ci-dockerfiles/<distro><version>-bootstrap-tester/Dockerfile`
- `.ci-dockerfiles/<distro><version>-bootstrap-tester/build-and-push.bash`
- `.release-notes/<distro><version>.md`

Existing files to edit:
- `.github/workflows/build-bootstrap-tester-image.yml` — one dropdown option + one job block
- `.github/workflows/pr.yml` and/or `.github/workflows/ponyup-tier2.yml` — bootstrap test jobs (one per arch; tier file for each is asked)
- `ponyup-init.sh` — distro detection case

Conditional edit (only if the canonical-example promotion is selected):
- `README.md`, `cmd/cli.pony`, `cmd/main.pony`, `cmd/cloudsmith.pony` — bump the canonical example platform string. (`cmd/packages.pony` has a *bare* distro reference in a docstring, not the full canonical-example form; treat separately if you want to refresh it. The grep recipes in step 13 catch both cases.)

Conditional edit (only if the new platform is the latest Alpine):
- `test/main.pony` — bump the `x86_64-linux-alpine<version>` test fixture

## Before you begin

- **Branch base:** start from a fresh `main`. `git checkout main && git pull`.
- **Tools:** Docker daemon running (`docker info` succeeds), `gh` authenticated, `git` configured to push to origin. If the Docker daemon isn't running, ask the user to start it — the agent typically can't start daemons itself.
- **`gh` token scopes needed:** `workflow` (for dispatching builds) and `read:packages` (for querying GHCR tags). Run `gh auth status` and confirm the `Token scopes:` line includes both. If missing: `gh auth refresh -s workflow,read:packages`. A 403 from the GHCR API in step 9 means missing scope, not a missing image.
- **Placeholders in this document:** every `<distro>`, `<version>`, `<tag>`, etc. is a placeholder for substitution. The angle brackets are not part of any command. Example for Alpine 3.24: `<distro>` → `alpine`, `<version>` → `3.24`.
- **Long-running waits:** steps 8 and 18 use `gh run watch --exit-status` and `gh pr checks --watch --exit-status`. The build wait is typically 20–40 minutes (multi-arch QEMU) and PR CI is 10+ minutes — both can exceed the agent's Bash tool timeout. Run them with `run_in_background: true` and check status periodically, or poll non-blocking variants (`gh run view <id> --json status,conclusion`, `gh pr checks <num>`).

## Procedure

The **structural exemplar** for the directory layout, `build-and-push.bash`, `build-bootstrap-tester-image.yml` job block, and CI bootstrap job entries is the most recent Alpine multi-arch bootstrap-tester. As of writing, that's `alpine3.23-bootstrap-tester`. Before starting, glance at `.ci-dockerfiles/` and pick whichever Alpine multi-arch bootstrap-tester is newest (`alpineX.Y-bootstrap-tester`); use it in place of `alpine3.23-bootstrap-tester` throughout this document.

### 1. Branch

```bash
git checkout main && git pull
git checkout -b add-<distro>-<version>-bootstrap-platform
```

### 2. ASK USER: SSL choice

Before writing the Dockerfile, surface the SSL decision to the user:

> "What `SSL=` value should the new bootstrap test use, and which dev package should the Dockerfile install? Existing precedent: Alpine entries use `SSL=libressl` + `libressl-dev`; Ubuntu entries use `SSL=3.0.x` + `libssl-dev`. The right choice depends on what the new distro packages and what you want to test against."

Surface the precedent as context. Don't pick for the user. Wait for the answer before proceeding to step 3.

The choice flows through three places that must agree:
1. The Dockerfile's installed dev package (step 3).
2. The `SSL=` value in each bootstrap job in `pr.yml`/`ponyup-tier2.yml` (step 11).
3. `.ci-scripts/test-bootstrap.sh` passes the value through; no edit needed there if the job sets `SSL=` correctly.

A mismatch surfaces as a link-time failure deep in CI.

### 3. Create the bootstrap-tester directory

```bash
mkdir -p .ci-dockerfiles/<distro><version>-bootstrap-tester
```

**Dockerfile.** Copy the most recent **same-distro-family** Dockerfile and adjust two things:
- `FROM <distro>:<version>` — bump the version.
- The SSL dev package — match the SSL choice from step 2.

Don't enumerate the package list yourself; copy it. Each distro family has accumulated specifics that aren't obvious from the conceptual list (e.g. Ubuntu Dockerfiles install `lsb-release` so `ponyup-init.sh`'s `lsb_release -d` detection works inside the container, plus `ca-certificates` and a `git config --global --add safe.directory` line). Don't trim packages without a concrete reason; the smoke test in step 4 will surface what's actually missing.

For Alpine adds, `alpine3.23-bootstrap-tester/Dockerfile` is the same-distro exemplar. For Ubuntu adds, `ubuntu24.04-bootstrap-tester/Dockerfile` is. (The cross-distro structural exemplar — for shape only, not contents — is the most recent Alpine bootstrap-tester.)

If adding a distro that isn't Alpine or Ubuntu, verify the base image is multi-arch first:

```bash
docker manifest inspect <distro>:<version> | jq '.manifests[].platform'
```

Both `linux/amd64` and `linux/arm64` must appear.

**build-and-push.bash.** Copy from the structural-exemplar bootstrap-tester (`alpine3.23-bootstrap-tester/build-and-push.bash`) and change only the `NAME` and the `BUILDER` prefix. The shape:

```bash
#!/bin/bash

set -o errexit
set -o nounset

#
# *** You should already be logged in to GHCR when you run this ***
#

NAME="ghcr.io/ponylang/ponyup-ci-<distro><version>-bootstrap-tester"
TODAY=$(date +%Y%m%d)
DOCKERFILE_DIR="$(dirname "$0")"
BUILDER="<distro><version>-builder-$(date +%s)"

docker buildx create --use --name "${BUILDER}"
docker buildx build --provenance false --sbom false --platform linux/arm64,linux/amd64 --pull --push -t "${NAME}:${TODAY}" "${DOCKERFILE_DIR}"
docker buildx rm "${BUILDER}"
```

Make the script executable: `chmod +x .ci-dockerfiles/<distro><version>-bootstrap-tester/build-and-push.bash`.

### 4. Local smoke test

Before pushing or dispatching anything, build the Dockerfile locally for amd64 explicitly:

```bash
docker build --pull --platform linux/amd64 .ci-dockerfiles/<distro><version>-bootstrap-tester/
```

`--platform linux/amd64` makes the smoke test deterministic regardless of host architecture. `--pull` forces a fresh base image rather than a stale local cache. This is a smoke test only — don't run `build-and-push.bash` locally (that would push to GHCR with today's date stamp).

If the build fails because Docker isn't running or the package manager can't reach the network, that's an environment issue — surface it to the user and stop. The agent typically can't start daemons or fix host networking on its own. If the build fails inside the image (package gone, repo URL invalid, base image not yet published, etc.): **STOP**. Surface the error to the user. Don't retry. Don't "fix" by tweaking the package list without confirmation — that's a design discussion.

The remote multi-platform build in step 7 cross-builds arm64 from x86-64 via QEMU. Local x86-64 success is a strong signal but not a guarantee for arm64; the GHA dispatch is the real arm64 verification.

### 5. Update `build-bootstrap-tester-image.yml`

Two edits, both mechanical:

**a. Add one dropdown option** (alphabetical across the whole list):

```yaml
options:
  ...
  - <distro><version>-bootstrap-tester
  ...
```

**b. Add one job block** by copying the structural-exemplar job (`alpine3_23-bootstrap-tester`) and substituting the version. Place the new job alphabetically among the sibling jobs.

The job map key replaces `.` with `_` (YAML map keys can't contain `.`): a version of `26.04` becomes `26_04` in the job key only — the `if:` filter value, the `name:` field, and the `bash` script path all keep the dot form. Reference shape:

```yaml
<distro><version_underscore>-bootstrap-tester:
  if: ${{ github.event.inputs.builder-name == '<distro><version>-bootstrap-tester' }}
  runs-on: ubuntu-latest

  name: <distro><version>-bootstrap-tester
  steps:
    - name: Checkout
      uses: actions/checkout@v6.0.2
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v4
      with:
        version: v0.23.0
    - name: Login to GitHub Container Registry
      uses: docker/login-action@v4
      with:
        registry: ghcr.io
        username: ${{ github.repository_owner }}
        password: ${{ secrets.GITHUB_TOKEN }}
    - name: Build and push
      run: bash .ci-dockerfiles/<distro><version>-bootstrap-tester/build-and-push.bash
```

`runs-on: ubuntu-latest` is correct — the multi-platform build cross-compiles arm64 via QEMU on an x86-64 runner. Don't change it.

**Dropdown ↔ directory invariant:** the dropdown option string is consumed by `bash .ci-dockerfiles/<option>/build-and-push.bash`. The option string must exactly match the bootstrap-tester directory name. A typo is silent failure (workflow runs `bash` against a non-existent path; only signal is workflow logs).

### 6. Commit and push the branch (push is a prerequisite for dispatch)

The workflow_dispatch in step 7 runs the workflow file from the branch on origin, so the branch must be pushed before dispatch. A WIP commit is fine here — it'll be squashed in step 17.

```bash
git add .ci-dockerfiles .github/workflows/build-bootstrap-tester-image.yml
git commit -m "WIP: add <distro> <version> bootstrap tester"
git push -u origin add-<distro>-<version>-bootstrap-platform
```

### 7. Dispatch the builder workflow from the branch

GHA `workflow_dispatch` runs the workflow file from the chosen ref, so the new dropdown option becomes available when targeting the branch.

```bash
gh workflow run build-bootstrap-tester-image.yml \
  --ref add-<distro>-<version>-bootstrap-platform \
  -f builder-name=<distro><version>-bootstrap-tester
```

If dispatch returns 403, the `gh` token lacks `workflow` scope — see "Before you begin."

### 8. Wait for the build to finish

The multi-platform build takes ~20–40 minutes (arm64 via QEMU is the slow leg) — well beyond the agent's foreground Bash timeout. Capture the run id first:

```bash
RUN_ID=$(gh run list --workflow=build-bootstrap-tester-image.yml \
  --branch=add-<distro>-<version>-bootstrap-platform \
  --limit=1 --json databaseId --jq '.[].databaseId')
```

Then either:
- Run `gh run watch "$RUN_ID" --exit-status` with `run_in_background: true` and wait for the completion notification, or
- Poll non-blocking with `gh run view "$RUN_ID" --json status,conclusion --jq '{status, conclusion}'` periodically until `status == "completed"`.

If the build fails: **STOP**. Read the failed logs with `gh run view "$RUN_ID" --log-failed` and surface the failure to the user. A common cause is a package or repo change for the new distro — that's a discussion, not something to silently work around.

### 9. Discover the published tag

The successful build pushes `ghcr.io/ponylang/ponyup-ci-<distro><version>-bootstrap-tester:YYYYMMDD`. Query GHCR:

```bash
gh api -X GET /orgs/ponylang/packages/container/ponyup-ci-<distro><version>-bootstrap-tester/versions \
  --jq '[.[].metadata.container.tags[]] | map(select(test("^[0-9]{8}$"))) | max'
```

The `select(test("^[0-9]{8}$"))` filter restricts to date-form tags (rejects `latest` or other future tags); `max` picks the most recent.

If the API returns 403, the `gh` token lacks `read:packages` — see "Before you begin." A 403 means missing scope, not a missing image.

### 10. ASK USER: tier placement

> "Where should each bootstrap job land — `pr.yml` (tier 1, runs on every PR) or `ponyup-tier2.yml` (tier 2, runs less often)? Pick independently for x86-64 and arm64. Current convention as context: latest x86-64 of each distro family in tier 1; everything else (including all arm64) in tier 2. But this is your call."

Surface the convention as context. Don't pick for the user. If the user picks tier 1 for arm64, surface that there's no arm64 Linux bootstrap precedent in `pr.yml` today, then proceed with their choice.

### 11. Add bootstrap test jobs to the chosen tier file(s)

You're adding **two jobs total — one per arch**. Pick a same-arch exemplar from the chosen tier file:

| Where you're adding | Exemplar to copy | Job shape |
|---|---|---|
| Tier 1 x86-64 | `x86-64-alpine3_23-bootstrap` (`pr.yml`) | `runs-on: ubuntu-latest` + `container:` block |
| Tier 1 arm64 | *no precedent today* (see note below) | — |
| Tier 2 x86-64 | `x86-64-alpine3_22-bootstrap` (`ponyup-tier2.yml`) | `runs-on: ubuntu-latest` + `container:` block |
| Tier 2 arm64, **Alpine add** | `arm64-alpine3_23-bootstrap` (`ponyup-tier2.yml`) | `runs-on: ubuntu-24.04-arm` + manual `docker pull` / `docker run` |
| Tier 2 arm64, **Ubuntu add** | `arm64-ubuntu24_04-bootstrap` (`ponyup-tier2.yml`) | `runs-on: ubuntu-24.04-arm` + `container:` block |

**The arm64 shape splits by distro family in tier 2**: Alpine arm64 uses manual `docker pull`/`docker run` (musl/arm64 GH Actions limitation with `container:`), Ubuntu arm64 uses the `container:` block. Pick the same-distro-family exemplar; don't copy the Alpine shape onto a Ubuntu add.

**Tier 1 arm64**: no arm64 Linux bootstrap job exists in `pr.yml` today. If the user picked tier 1 for arm64 in step 10, copy the matching tier-2 arm64 shape (Alpine or Ubuntu) and drop the tier-2-specific pieces:
- `needs: check-for-changes`
- `if: needs.check-for-changes.outputs.has-changes == 'true'`
- The `with: ref: ${{ inputs.ref || github.sha }}` block on `actions/checkout`
- The full `Send alert on failure` Zulip step

Surface the precedent gap to the user before proceeding.

**Mechanical substitutions** in the copied entry:
- Version number in `name:` (e.g. `arm64 Alpine 3.23 bootstrap` → `arm64 Alpine 3.24 bootstrap`).
- Image tag string (the GHCR image and tag from step 9).
- `SSL=` value from the SSL choice in step 2.

Keep `runs-on:`, the overall job shape, and any `Send alert on failure` Zulip step the exemplar carries (tier 2 entries have one; tier 1 entries don't). **Tier 2 entries also carry `needs: check-for-changes` and `if: needs.check-for-changes.outputs.has-changes == 'true'` guards** — preserve them.

**Don't use `ubuntu22_04-bootstrap` (lines around 278–301 of `ponyup-tier2.yml`) as an exemplar** — legacy single-arch shape, stale image tag, no arm64 sibling.

**Note on `pr.yml` path filters**: tier 1 (`pr.yml`) excludes markdown, yml/yaml (except `pr.yml` itself), and `.ci-dockerfiles/**`. A PR that only touches those won't trigger tier 1. This platform-add typically also touches `ponyup-init.sh` (step 12) and possibly `pr.yml` itself (if tier 1 was picked) — both are non-excluded, so tier 1 will run on this PR. If a future yml-only or dockerfile-only follow-up PR doesn't trigger tier 1, that's why.

### 12. Update `ponyup-init.sh`

The bootstrap test in step 11 exercises `ponyup-init.sh` end-to-end on the new distro, so the detection case must land in the same PR for CI to pass.

Add the distro detection case in the appropriate `case` block:

- **Alpine**: `*<version>.*` → `alpine<version>` in the musl block (under `case "$(cat /etc/alpine-release)"`).
- **Ubuntu**: `*"Ubuntu <version>"*` → `ubuntu<version>` in the gnu block (under `case "$(lsb_release -d)"`). Also add derivative-distro cases that already ship with this Ubuntu version:
  - **Pop!_OS**: tracks Ubuntu LTS version directly. Pop!_OS X.Y → `ubuntu<X.Y>`.
  - **Linux Mint**: uses its own counter. Mint 21 = Ubuntu 22.04, Mint 22 = Ubuntu 24.04, Mint 23 = Ubuntu 26.04 (if precedent holds; verify against current Mint release notes before adding).

  If the derivative distro hasn't shipped a release based on this Ubuntu version yet, defer that case to a later PR — don't add a case for a Mint or Pop!_OS version that doesn't exist.

  **Known gap (out of scope to backfill)**: as of this writing, `ponyup-init.sh` has Mint 21 (Ubuntu 22.04) but is missing Mint 22 (Ubuntu 24.04). Adding the case for the new Ubuntu version's matching Mint release, *if such a Mint release has shipped at the time of the PR*, is in scope. Backfilling Mint 22 is *not* in scope for this skill — open a separate issue if you want it tracked.

### 13. ASK USER: canonical-example promotion

> "Should this become the canonical example platform shown in `ponyup --help`, README, and code comments? Ubuntu 24.04 (#303) was promoted; Alpine 3.23 (#343) was not. The promotion bumps every occurrence of the current canonical example string."

Files containing the canonical example string today: `README.md` (multiple occurrences), `cmd/cli.pony`, `cmd/main.pony`, `cmd/cloudsmith.pony` (a comment that was missed in #303 and is currently stale at `ubuntu22.04` — promote it too). `cmd/packages.pony` has a *bare* distro reference (e.g. `(ubuntu24.04)`) inside a docstring, not the full `x86_64-linux-...` form; the second grep below catches it for separate consideration.

Don't trust line numbers in this skill — they go stale. Run these greps before editing to enumerate the current locations:

```bash
grep -rn "x86_64-linux-<old-distro>" cmd/ README.md
grep -rEn "x86_64-linux-(ubuntu|alpine)" cmd/ README.md
grep -rEn "(ubuntu|alpine)[0-9]+\.[0-9]+" cmd/
```

The first finds occurrences of the current canonical string. The second is unanchored and catches stale historical references like the `cloudsmith.pony` comment. The third catches bare distro references in docstrings (e.g. `cmd/packages.pony`) — decide separately whether those should be promoted. Use all three — the canonical-string locations have shifted historically (e.g. PR #387 removed several `cli.pony` occurrences) and may shift again.

### 14. For new Alpine adds: bump the test platform string

`test/main.pony` contains a `"x86_64-linux-alpine<version>"` fixture that tracks "most recent Alpine" per commit `3ba53c3`. When adding a new Alpine version that becomes the latest, bump this string. This is independent of the canonical-example promotion (always bump for new latest-Alpine adds; never bump for non-Alpine adds). Locate it with:

```bash
grep -n 'x86_64-linux-alpine' test/main.pony
```

### 15. Add release note

Create `.release-notes/<distro><version>.md`:

```markdown
## Add <Distro> <Version> as a supported platform

We've added support for <Distro> <Version>. This means that if you are using `ponyup` on an arm64 or amd64 system with <Distro> <Version>, it will now recognize it as a supported platform and allow you to install `ponyc` and other related packages.
```

### 16. Sanity check coverage

```bash
git diff --stat main
grep -rn "<distro><version>" .github/workflows/ .ci-dockerfiles/ .release-notes/ ponyup-init.sh README.md cmd/ test/
```

Note: the YAML job-key form replaces `.` with `_` (e.g. `ubuntu26_04-bootstrap-tester`), which the dotted grep won't find. Check the workflow file separately for the underscore form.

### 17. Squash, push, open PR

The PR title must exactly match the release-note H2 from step 15: `Add <Distro> <Version> as a supported platform`. Both end up as public-facing CHANGELOG content, so they must agree. The commit message matches too (it becomes the squash-merge commit subject).

The PR also needs the `changelog - added` label so release-notes aggregation picks up the entry under the right CHANGELOG section.

```bash
git fetch origin main
git reset --soft origin/main
git add -A
git commit -m "Add <Distro> <Version> as a supported platform"
git push --force-with-lease

PR_URL=$(gh pr create \
  --title "Add <Distro> <Version> as a supported platform" \
  --label "changelog - added" \
  --body "Adds <Distro> <Version> as a supported bootstrap-test platform. Bootstrap-tester image, CI bootstrap jobs, and \`ponyup-init.sh\` detection are all included.")
PR_NUM=${PR_URL##*/}
```

PR body: short summary; no `## Summary` header; no `Test plan` section.

### 18. Wait for CI, then squash-merge

The PR-checks wait can run 10+ minutes — beyond the agent's foreground Bash timeout. Run with `run_in_background: true` and wait for the completion notification, or poll non-blocking with `gh pr checks "$PR_NUM" --json state` until all checks have a final state.

```bash
gh pr checks "$PR_NUM" --watch --exit-status
gh pr merge "$PR_NUM" --squash --delete-branch
git checkout main && git pull
```

`--watch --exit-status` blocks until checks finish and exits non-zero if any failed. If checks fail: **STOP**. Read the failure with `gh pr checks "$PR_NUM"` to see which check, drill into its logs, and surface to the user. Don't retry the merge.

`--squash --delete-branch` matches the ponylang merge convention (squash merge only) and removes both the remote and local branch. The `git checkout main && git pull` afterward returns you to an up-to-date main.

After this step, the platform-add work is complete. **No Last Week in Pony comment.** Unlike the analogous ponyc skill, ponyup adds don't post a per-platform LWIP comment — the release note (folded into the next ponyup release's CHANGELOG) and the corresponding ponyc release-target announcement together cover it.

## Failure modes — when to stop and ask

- **Local Dockerfile build fails inside the image.** Package gone, repo URL invalid, base image not yet published. Don't tweak the package list or "fix forward" without confirmation.
- **GHA builder dispatch fails.** Read run logs with `gh run view <id> --log-failed`. Most causes are the same as above.
- **GHCR tag query returns no result.** Build may not have pushed (auth failure, network error). Check the workflow run logs. A 403 response means missing `read:packages` scope, not a missing image.
- **arm64 build fails but amd64 succeeds (or vice versa).** Multi-platform `docker buildx` produces a single manifest covering both arches; if either platform fails, the whole build fails and nothing gets pushed. Triage from the failed-platform logs.
- **PR CI checks fail.** Don't retry the merge. Read the failed check's logs, surface to the user.

## Anti-patterns

- **Don't conflate this with non-bootstrap CI test workflows.** This skill targets bootstrap testing only — exercising `ponyup-init.sh` end-to-end on a new platform.
- **Don't migrate `ubuntu22.04-bootstrap-tester` to multi-arch as a side effect.** That's a separate change.
- **Don't use `ubuntu22_04-bootstrap` (tier 2) as a structural exemplar** — legacy single-arch shape, stale image tag, no arm64 sibling.
- **Don't bake in a default for SSL choice or tier placement.** Both are user decisions; surface the precedent as context and ask.
- **Don't skip the smoke test to save time.** A failed GHA multi-platform build is a 30-minute round-trip plus user-attention cost. A failed local build is 30 seconds.
- **Don't run `build-and-push.bash` locally.** It pushes. The smoke test is `docker build` only.
