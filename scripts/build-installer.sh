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

command -v python3 >/dev/null 2>&1 || {
	echo "error: missing python3" >&2
	exit 1
}

# 1. Syntax check all Python files in the installer
python3 -m compileall -q "${PKG_DIR}/astra_installer"

# 2. Run unit tests if tests directory exists
if [[ -d "${REPO_ROOT}/tests/installer" ]]; then
	python3 -m unittest discover -s "${REPO_ROOT}/tests/installer"
fi

printf 'AstraOS installer verified successfully.\n'
