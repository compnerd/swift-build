# Release Process

The swift-build repository needs a new release branch that tracks a corresponding Swift release
branch, every time Swift cuts a new release branch. This branch is responsible for building the
toolchain for that branch only.

This guide details which things need to be updated when a new `swift-build` release branch is
created.

## Prerequisites

- Determine the Swift version for the new branch (e.g., `6.4.0`)
- Ensure upstream Swift has created their corresponding release branch
- Have write access to the repository

## Steps to Create a New Release Branch

### 1. Create the Release Branch

```bash
# From main branch
git checkout main
git pull
git checkout -b release/6.4
```

### 2. Update `default.xml`

The `repo` tool manifest is specified in the `default.xml` file. Branches should follow the
release conventions instead of main.

Edit `default.xml` and update the following:

1. **Default revision** - the primary branch for most repos:
   ```xml
   <default revision="release/6.4" sync-c="true" sync-tags="false" />
   ```
   Change from `main` to `release/6.4`.

2. **LLVM Project revision** - uses a different convention:
   ```xml
   <project remote="github" name="swiftlang/llvm-project" path="llvm-project" revision="swift/release/6.4" />
   ```
   Change from the current stable branch (e.g., `stable/21.x`) to `swift/release/6.4`.

3. **Review other projects** - Most will use the default revision or explicit tags, but verify
   any that might need release-specific branches. You can look at the `default.xml` file in the
   prior release branch to see which repos need custom conventions.

### 3. Update `build-toolchain.yml`

The `build-toolchain.yml` workflow needs several updates for the new release branch.

Edit `.github/workflows/build-toolchain.yml`:

#### 3.1. Update `swift_version` Default

The branch that the `repo` tool uses is inferred from the Swift version given to the workflow.
For the `workflow_call` inputs section (around line 73), update:

```yaml
swift_version:
  description: 'Swift Version'
  default: '6.4.0'  # Change from '0.0.0'
  required: false
  type: string
```

#### 3.2. Update Repository Revisions for Untagged Repos

In the context job's script section where `INPUT_SWIFT_TAG` is set (around lines 355-376),
update the repositories that don't have tags to point to the release branch instead of main:

```bash
swift_build_revision=refs/heads/release/6.4
swift_format_revision=refs/heads/release/6.4
swift_foundation_revison=refs/heads/release/6.4
swift_foundation_icu_revision=refs/heads/release/6.4
swift_installer_scripts_revision=refs/heads/release/6.4
swift_lmdb_revision=refs/heads/release/6.4
swift_subprocess_revision=refs/heads/release/6.4
swift_testing_revision=refs/heads/release/6.4
```

Change all instances from `refs/heads/main` to `refs/heads/release/6.4`.

#### 3.3. Update Snapshot Job Checkout Ref

In the `snapshot` job (around line 850), update the checkout reference:

```yaml
- uses: actions/checkout@v4.2.2
  with:
    ref: release/6.4  # Change from refs/heads/main
    show-progress: false
```

Note: The snapshot job will create a PR with the updated `stable.xml` instead of pushing
directly to the branch.

### 4. Create the Schedule Workflow on the Release Branch

Create `.github/workflows/release-6-4-swift-toolchain-schedule.yml` on the release branch.
Use a local reference (without `@release/6.4`) so it can be triggered directly for testing:

```yaml
name: Release 6.4 Toolchains

on:
  workflow_dispatch:

jobs:
  build-release-6_4:
    # Use local reference so this workflow can be dispatched directly from the release branch
    # for testing without any modifications. The @release/6.4 reference will be added when
    # copying to main for scheduled runs.
    uses: ./.github/workflows/build-toolchain.yml
    with:
      # Source/Repository Configuration
      ci_build_branch: ${{ github.ref }}
      swift_version: "6.4.0"
      # Build Configuration
      windows_build_arch: amd64
      build_android: true
      android_api_level: 28
      # Output/Publishing
      create_release: ${{ github.event_name == 'schedule' }}
      create_snapshot: ${{ github.event_name == 'schedule' }}
      # Infrastructure/Runners
      windows_x64_default_runner: <your-x64-runner-label>
      windows_x64_compilers_runner: <your-x64-large-runner-label>
      windows_arm64_default_runner: <your-arm64-runner-label>
      windows_arm64_compilers_runner: <your-arm64-large-runner-label>
    secrets: inherit
    permissions:
      attestations: write
      contents: write
      packages: write
      id-token: write
```

**Important Notes:**
- The `uses:` line uses a local reference (`./.github/workflows/build-toolchain.yml`) on the
  release branch, which allows the workflow to be triggered directly for testing
- The `swift_version` must match the release (use full semver: `"6.4.0"`)
- The `ci_build_branch` uses `github.ref` on the release branch so it automatically uses
  whatever branch the workflow is triggered from (useful for testing)
- `create_release` and `create_snapshot` are only true for scheduled runs, not manual triggers
  (this prevents accidental releases during testing)
- Replace the runner placeholders (`<your-*-runner-label>`) with your actual GitHub Actions
  runner labels. You'll typically need both standard and large/high-core-count runners for the
  compilers job.

### 5. Commit and Push the Release Branch

```bash
git add default.xml .github/workflows/build-toolchain.yml \
        .github/workflows/release-6-4-swift-toolchain-schedule.yml
git commit -m "Prepare release/6.4 branch

- Update default.xml to use release/6.4 branches
- Update build-toolchain.yml swift_version default to 6.4.0
- Update repository revisions for untagged repos
- Update snapshot job to target release/6.4 branch
- Add schedule workflow for release/6.4"

git push origin release/6.4
```

**Note:** For initial branch creation, pushing directly is acceptable. For subsequent changes to
release branches, create a PR instead of pushing directly.

### 6. Copy and Modify the Schedule Workflow on Main

The schedule workflow needs to exist on `main` for GitHub Actions to trigger it on schedule.
Copy the workflow file from the release branch and create a PR:

```bash
git checkout main
git pull
git checkout -b add-release-6-4-schedule
git checkout release/6.4 -- .github/workflows/release-6-4-swift-toolchain-schedule.yml
```

Edit `.github/workflows/release-6-4-swift-toolchain-schedule.yml`:

1. **Change the `uses:` line** to reference the release branch explicitly:
   ```yaml
   uses: compnerd/swift-build/.github/workflows/build-toolchain.yml@release/6.4
   ```

2. **Change `ci_build_branch`** to hardcode the release branch:
   ```yaml
   ci_build_branch: refs/heads/release/6.4
   ```

3. **Add the schedule trigger** back:
   ```yaml
   on:
     workflow_dispatch:
     # Schedule to build a new release toolchain daily.
     schedule:
       - cron: "0 20 * * *"
   ```

Then commit and push:

```bash
git add .github/workflows/release-6-4-swift-toolchain-schedule.yml
git commit -m "Add schedule workflow for release/6.4 toolchains"
git push origin add-release-6-4-schedule
```

Create a PR to `main` with these changes.

### 7. Verify the Setup

1. **Trigger the schedule workflow manually** from the GitHub UI:
   - Go to Actions → "Release 6.4 Toolchains"
   - Click "Run workflow" from the `main` branch
2. **Check that it runs** and uses the correct release branch
3. **Verify the build artifacts** are tagged correctly (e.g., `swift-6.4.0-YYYYMMDD.N`)

## Testing Changes to a Release Branch

The schedule workflow on the release branch is already configured to use a local reference
(`./.github/workflows/build-toolchain.yml`), which means you can test changes directly without
any workflow modifications.

If you're making changes on a release branch (e.g., `release/6.3`) and want to test before
merging:

1. **Create a test branch from the release branch:**
   ```bash
   git checkout release/6.3
   git pull
   git checkout -b test/my-release-changes
   ```

2. **Make your changes** to `build-toolchain.yml`, `swift-toolchain.yml`, or other files

3. **Commit and push your test branch:**
   ```bash
   git add .
   git commit -m "Test: <description of changes>"
   git push origin test/my-release-changes
   ```

4. **Trigger the schedule workflow** from the GitHub UI:
   - Go to Actions → "Release 6.3 Toolchains" (or the appropriate release workflow)
   - Click "Run workflow"
   - Select your test branch from the dropdown
   - Click "Run workflow"

   The workflow will use the local `./.github/workflows/build-toolchain.yml` from your test
   branch, and `ci_build_branch` will automatically use your test branch via `github.ref`.

5. **Once validated, create a PR to the release branch** targeting `release/6.3`. After the PR is
   reviewed and merged, clean up the test branch:
   ```bash
   git branch -D test/my-release-changes
   git push origin --delete test/my-release-changes
   ```

**Important Notes:**
- The workflow on the release branch already uses a local reference, so no modifications are
  needed for testing
- The `create_release` and `create_snapshot` parameters are already configured to only trigger
  on `schedule` events, so manual workflow_dispatch runs won't create releases
- The `ci_build_branch` uses `github.ref` which automatically points to your test branch when
  triggered from it

## Summary Checklist

**On `release/6.4` branch:**
- [ ] Update `default.xml` default revision to `release/6.4`
- [ ] Update `default.xml` llvm-project revision to `swift/release/6.4`
- [ ] Update `build-toolchain.yml` swift_version default to `6.4.0`
- [ ] Update `build-toolchain.yml` untagged repo revisions to `refs/heads/release/6.4`
- [ ] Update `build-toolchain.yml` snapshot job checkout ref to `release/6.4`
- [ ] Update `build-toolchain.yml` snapshot job push target to `HEAD:release/6.4`
- [ ] Create `release-6-4-swift-toolchain-schedule.yml` on the release branch
- [ ] Update runner labels to match your infrastructure
- [ ] Commit and push release branch

**On `main` branch:**
- [ ] Copy `release-6-4-swift-toolchain-schedule.yml` from release branch to feature branch
- [ ] Modify the workflow to use `@release/6.4` and add schedule trigger
- [ ] Push feature branch and create PR with schedule workflow changes
- [ ] Merge PR after review

**Verification:**
- [ ] Manually trigger the schedule workflow from main branch
- [ ] Verify correct branch usage (check logs for ci-build checkout)
- [ ] Check build artifact tags match expected format
