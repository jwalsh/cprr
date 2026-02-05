#!/usr/bin/env bash
# release.sh - Semantic versioning release tool
# Usage: ./scripts/release.sh [major|minor|patch] [--dry-run]
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}==>${NC} $*"; }
log_warn() { echo -e "${YELLOW}==>${NC} $*"; }
log_error() { echo -e "${RED}==>${NC} $*" >&2; }

# Parse arguments
BUMP_TYPE="${1:-}"
DRY_RUN=false
for arg in "$@"; do
    case $arg in
        --dry-run|-n) DRY_RUN=true ;;
    esac
done

if [[ -z "$BUMP_TYPE" ]] || [[ ! "$BUMP_TYPE" =~ ^(major|minor|patch)$ ]]; then
    echo "Usage: $0 <major|minor|patch> [--dry-run]"
    echo ""
    echo "Examples:"
    echo "  $0 patch          # 0.1.0 -> 0.1.1"
    echo "  $0 minor          # 0.1.1 -> 0.2.0"
    echo "  $0 major          # 0.2.0 -> 1.0.0"
    echo "  $0 patch --dry-run"
    exit 1
fi

# Get current version from latest tag
CURRENT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
CURRENT_VERSION="${CURRENT_TAG#v}"

# Parse version components
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
MAJOR=${MAJOR:-0}
MINOR=${MINOR:-0}
PATCH=${PATCH:-0}

# Bump version
case $BUMP_TYPE in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
NEW_TAG="v${NEW_VERSION}"

log_info "Current version: $CURRENT_TAG"
log_info "New version:     $NEW_TAG"

# Check for uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
    log_error "Uncommitted changes detected. Commit or stash first."
    exit 1
fi

# Check we're on main branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$BRANCH" != "main" ]]; then
    log_warn "Not on main branch (on: $BRANCH)"
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# Generate changelog since last tag
log_info "Changes since $CURRENT_TAG:"
CHANGELOG=$(git log "${CURRENT_TAG}..HEAD" --pretty=format:"- %s" 2>/dev/null || git log --pretty=format:"- %s")
echo "$CHANGELOG"
echo ""

if $DRY_RUN; then
    log_warn "[DRY RUN] Would create tag: $NEW_TAG"
    log_warn "[DRY RUN] Would push tag to origin"
    log_warn "[DRY RUN] Would create GitHub release"
    exit 0
fi

# Confirm
read -p "Create release $NEW_TAG? [y/N] " -n 1 -r
echo
[[ ! $REPLY =~ ^[Yy]$ ]] && exit 1

# Create annotated tag
log_info "Creating tag $NEW_TAG..."
git tag -a "$NEW_TAG" -m "Release $NEW_TAG

$CHANGELOG"

# Push tag
log_info "Pushing tag to origin..."
git push origin "$NEW_TAG"

# Create GitHub release (if gh available)
if command -v gh &>/dev/null; then
    log_info "Creating GitHub release..."
    gh release create "$NEW_TAG" \
        --title "$NEW_TAG" \
        --notes "$CHANGELOG" \
        --generate-notes
    log_info "Release created: https://github.com/jwalsh/cprr/releases/tag/$NEW_TAG"
else
    log_warn "gh CLI not found. Create release manually at:"
    echo "  https://github.com/jwalsh/cprr/releases/new?tag=$NEW_TAG"
fi

log_info "Done! Released $NEW_TAG"
