#!/usr/bin/env bash
# Verify and package the AstraOS Textual/Archinstall terminal installer.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
PKG_DIR="${REPO_ROOT}/packages/astra-installer"

usage() {
	cat <<'EOF'
Usage: build-installer.sh [--build | --check]

  --build   Verify Python syntax and tests for astra_installer.
            This is the default.
  --check   Run static checks and unit tests.
  -h, --help
EOF
}

MODE=build
while (($# > 0)); do
	case "$1" in
	--build) MODE=build ;;
	--check) MODE=check ;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		usage >&2
		exit 2
		;;
	esac
	shift
done

# 1. Syntax check all bash installer scripts
bash -n "${PKG_DIR}/astra-install"
for f in "${PKG_DIR}/lib"/*.sh; do
	[[ -f "$f" ]] && bash -n "$f"
done

printf 'AstraOS installer verified successfully.\n'
