#!/usr/bin/env bash
#
# generate-lockfile.sh
#
# Generates a package-lock.json for openclaw that includes all workspace
# dependencies (UI, extensions, packages). This is needed because openclaw
# uses pnpm workspaces, but Nix's buildNpmPackage requires npm's package-lock.json.
#
# Usage:
#   ./generate-lockfile.sh [VERSION]
#
# Examples:
#   ./generate-lockfile.sh           # Uses default version
#   ./generate-lockfile.sh 2026.2.9  # Specific version
#

set -euo pipefail

# Configuration
VERSION="${1:-2026.2.19}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"
TEMP_DIR=$(mktemp -d)

# Cleanup on exit
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo "=== Openclaw package-lock.json Generator ==="
echo "Version: v${VERSION}"
echo "Output:  ${OUTPUT_DIR}/package-lock.json"
echo ""

# Step 1: Clone the repository
echo "[1/4] Cloning openclaw v${VERSION}..."
git clone --depth 1 --branch "v${VERSION}" \
    https://github.com/openclaw/openclaw.git "$TEMP_DIR" 2>&1 | grep -v "^Note:" || true

cd "$TEMP_DIR"

# Step 2: Add npm workspaces to package.json
# (pnpm uses pnpm-workspace.yaml, npm uses "workspaces" field in package.json)
echo "[2/4] Adding npm workspaces configuration..."
jq '. + {"workspaces": ["ui", "packages/*", "extensions/*"]}' package.json > tmp.json
mv tmp.json package.json

# Step 3: Replace pnpm workspace:* protocol with *
# (npm doesn't understand the workspace: protocol)
echo "[3/4] Replacing workspace:* protocol references..."
find . -name "package.json" -exec sed -i 's/"workspace:\*"/"*"/g' {} \;

# Step 4: Generate package-lock.json with all workspace dependencies
echo "[4/4] Generating package-lock.json (this may take a while)..."
npm install --package-lock-only --workspaces --include-workspace-root 2>&1 | tail -5

# Copy result
cp package-lock.json "$OUTPUT_DIR/"

echo ""
echo "=== Success ==="
echo "Generated: ${OUTPUT_DIR}/package-lock.json"
echo "Size: $(du -h "${OUTPUT_DIR}/package-lock.json" | cut -f1)"
echo "Packages: $(grep -c '"resolved"' "${OUTPUT_DIR}/package-lock.json") dependencies"
echo ""
echo "Next steps:"
echo "  1. Update npmDepsHash in package.nix (run 'nix build' to get the new hash)"
echo "  2. Rebuild with 'nix build .'"
