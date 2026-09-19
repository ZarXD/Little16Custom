#!/usr/bin/env bash
# makerepo.sh — rebuild the Sileo/Cydia repo inside docs/ from the latest debs.
# Needs: gh (to fetch the release) or drop .deb files into docs/packages manually.
# Needs: dpkg-scanpackages (package "dpkg-dev" on Debian/Ubuntu).
set -euo pipefail

REPO="ZarXD/Little16Custom"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE="$ROOT/docs"
PKGDIR="$SITE/packages"

mkdir -p "$PKGDIR"

echo "==> Fetching latest debs from GitHub release..."
if command -v gh >/dev/null 2>&1; then
  gh release download -R "$REPO" --pattern "*.deb" --dir "$PKGDIR" --clobber
else
  echo "    gh not found — please drop .deb files into $PKGDIR manually."
fi
ls -la "$PKGDIR"

command -v dpkg-scanpackages >/dev/null 2>&1 || {
  echo "error: dpkg-scanpackages missing (install dpkg-dev)" >&2; exit 1
}

echo "==> Generating Packages index..."
cd "$SITE"
dpkg-scanpackages --multiversion packages /dev/null > Packages
gzip -9c Packages > Packages.gz

UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen || echo "little16")
DATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")
{
  echo "Origin: Little16"
  echo "Label: Little16"
  echo "Suite: stable"
  echo "Version: 1.0"
  echo "Codename: little16"
  echo "Date: $DATE"
  echo "Architectures: iphoneos-arm64 iphoneos-arm64e"
  echo "Description: Little16 - iPhone X gestures for iOS 16"
  echo "SHA256:"
  echo " $(sha256sum Packages  | cut -d' ' -f1) $(stat -c%s Packages)  Packages"
  echo " $(sha256sum Packages.gz | cut -d' ' -f1) $(stat -c%s Packages.gz) Packages.gz"
} > Release

echo "==> Done. Repo hidup di $SITE (commit: Packages, Packages.gz, Release, packages/)."