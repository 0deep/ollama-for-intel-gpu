# GitHub Actions Workflows Guide

This document explains how to use GitHub Actions workflows in the `ollama-for-intel-gpu` project.

## 📋 Table of Contents

1. [Workflows Overview](#workflows-overview)
2. [Build and Push Workflow](#build-and-push-workflow)
3. [Release Workflow](#release-workflow)
4. [Initial Setup](#initial-setup)

## Workflows Overview

The project has 4 main GitHub Actions workflows:

| Workflow | File | Purpose |
|----------|------|---------|
| Build and Push | `.github/workflows/build-and-push.yml` | Automated build and test |
| Release | `.github/workflows/release.yml` | Automated version releases |
| Submodule Sync | `.github/workflows/submodule-sync.yml` | Automated Ollama submodule updates |
| Build on Submodule Update | `.github/workflows/build-on-submodule-update.yml` | Build validation on submodule updates |

## Build and Push Workflow

### 🔄 Automatic Trigger Conditions

The workflow runs automatically when:

- Push to `main` or `develop` branch
- Pull Request created or updated
- Version tag pushed (e.g., `v1.0.0`)

### 📦 Workflow Steps

1. **Checkout Code**: Clone repository including submodules
2. **Setup Docker Buildx**: Configure multi-platform build environment
3. **Registry Login**: Authenticate with GitHub Container Registry
4. **Extract Metadata**: Generate tags and labels
5. **Build Docker Image**: Build with caching
6. **Test Image**: Verify basic functionality
7. **Push Image**: Push to GHCR (except PRs)
8. **Generate Summary**: Display results in GitHub Actions summary

### 🏷️ Generated Tags

| Event | Tag Examples |
|-------|--------------|
| `main` branch push | `latest`, `main`, `main-abc1234` |
| `develop` branch push | `develop`, `develop-def5678` |
| Tag `v1.2.3` push | `v1.2.3`, `1.2.3`, `1.2`, `1`, `latest` |
| PR #42 | `pr-42` |

### 💻 Manual Execution

1. Go to GitHub repository → **Actions** tab
2. Select **Build and Push Docker Image**
3. Click **Run workflow**
4. Select branch and click **Run workflow**

## Release Workflow

### 🚀 How to Create a Release

#### Method 1: Auto-release with Git Tag

```bash
# Create tag locally
git tag v1.0.0

# Push tag to remote
git push origin v1.0.0
```

#### Method 2: Manual Workflow Execution

1. GitHub → **Actions** → **Release**
2. Click **Run workflow**
3. Enter version (e.g., `v1.0.0`)
4. Execute **Run workflow**

### 📝 Release Contents

- **Changelog**: All commit logs since previous tag
- **Release Notes**: Auto-generated GitHub notes
- **Docker Images**: Built and deployed with multiple tags
  - `v1.0.0`
  - `1.0.0`
  - `1.0`
  - `1`
  - `latest`

## Initial Setup

### 1. Enable GitHub Container Registry

For first-time use in the repository:

1. Repository **Settings** → **Actions** → **General**
2. In **Workflow permissions** section:
   - ✅ Select **Read and write permissions**
   - ✅ Check **Allow GitHub Actions to create and approve pull requests**

### 2. Package Visibility Settings

After first build:

1. Check repository's **Packages** section
2. Click on created package
3. **Package settings** → **Change visibility**
4. Select desired visibility (Public/Private)

### 3. Environment Variables (Optional)

If additional configuration is needed:

```bash
# Repository Settings → Secrets and variables → Actions
# You can add the following secrets:

DOCKERHUB_USERNAME  # For Docker Hub usage
DOCKERHUB_TOKEN     # For Docker Hub usage
```

## 🎯 Usage Examples

### Development Workflow

```bash
# 1. Create feature branch
git checkout -b feature/new-feature

# 2. Make changes and commit
git add .
git commit -m "Add new feature"

# 3. Push to remote
git push origin feature/new-feature

# 4. Create Pull Request
# → GitHub Actions automatically runs build and test
```

### Release Workflow

```bash
# 1. Switch to main branch
git checkout main
git pull origin main

# 2. Create version tag
git tag -a v1.0.0 -m "Release version 1.0.0"

# 3. Push tag
git push origin v1.0.0

# → GitHub Actions automatically:
#   - Creates GitHub Release
#   - Generates Changelog
#   - Builds and deploys Docker images (multiple tags)
```

### Image Download

```bash
# Latest version
docker pull ghcr.io/YOUR_USERNAME/ollama-for-intel-gpu:latest

# Specific version
docker pull ghcr.io/YOUR_USERNAME/ollama-for-intel-gpu:v1.0.0

# Development version
docker pull ghcr.io/YOUR_USERNAME/ollama-for-intel-gpu:develop
```

### Submodule Auto-update Workflow

```bash
# Automatic execution (daily at 3 AM UTC)
# → Checks Ollama submodule for latest commits
# → Auto-creates PR if changes detected

# Manual execution
# 1. GitHub → Actions → Sync Submodule (Ollama)
# 2. Click Run workflow
# 3. Configure options:
#    - branch: Ollama branch to track (default: main)
#    - force_update: Force update even without changes

# → When PR is created, build workflow runs automatically
# → On successful build, auto-comments on PR
# → After review and merge, updated to latest Ollama
```

## 🔍 Troubleshooting

### Build Failure

1. Click failed workflow in **Actions** tab
2. Check failed step
3. Review logs

Common issues:
- **Submodule errors**: Check `.gitmodules` file
- **Permission errors**: Check Repository Settings → Actions permissions
- **Docker build errors**: Verify `Dockerfile` syntax

### Image Push Failure

```bash
# Check permissions
# Settings → Actions → General → Workflow permissions
# Requires "Read and write permissions"
```

### Cache Issues

To reset cache:
1. **Actions** → **Caches**
2. Delete relevant cache
3. Re-run workflow

### Submodule Sync Issues

#### PR Not Created
- Normal behavior when Ollama repository has no new commits
- Use `force_update` in manual trigger if force update needed

#### Build Not Auto-running
1. Verify PR has `submodule-update` label
2. Settings → Actions → General → Workflow permissions:
   - Enable "Allow GitHub Actions to create and approve pull requests"

#### Submodule Commit Conflict
```bash
# Resolve manually locally
git submodule update --remote ollama
git add ollama
git commit -m "chore: sync ollama submodule"
git push
```

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Buildx](https://docs.docker.com/buildx/working-with-buildx/)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Git Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules)

## 💡 Tips

### Reduce Build Time

- GitHub Actions uses Buildx caching to reduce build time
- First build takes time, but subsequent builds are much faster

### Branch Strategy

Recommended branch strategy:
- `main`: Stable version, production deployment
- `develop`: Features in development
- `feature/*`: Feature branches
- `hotfix/*`: Emergency fixes
- `auto/*`: Auto-generated branches (submodule updates, etc.)

### Semantic Versioning

Version tags follow [Semantic Versioning](https://semver.org/):
- `v1.0.0`: Major.Minor.Patch
- Major: Breaking changes
- Minor: New features (backward compatible)
- Patch: Bug fixes

### Submodule Update Strategy

- **Automatic Monitoring**: Daily checks to stay up-to-date
- **PR Review**: Review changes via auto-PR before merging
- **Test First**: Verify build success before merging
- **Specific Version**: Manually specify branch to track specific Ollama tag

## ✅ Checklist

Project setup completion checklist:

- [ ] GitHub Actions permissions configured
- [ ] First build successful
- [ ] Package visibility settings complete
- [ ] Image pull test complete
- [ ] Release process tested
- [ ] Submodule sync workflow tested
- [ ] Auto PR creation and build validation confirmed
