#!/usr/bin/env bash
# Build the Rust/Tauri AstraOS installer and copy the binary into the package
# tree where build-iso.sh expects it.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
SRC="${REPO_ROOT}/installer/src-tauri"
OUT="${SRC}/target/release/astra-installer"
PKG_BIN="${REPO_ROOT}/packages/astra-installer/astra-installer-gui"

usage() {
	cat <<'EOF'
Usage: build-installer.sh [--build | --check]

  --build   Build the release binary and copy it into packages/astra-installer.
            This is the default.
  --check   Run cargo check and the Rust unit tests without copying the binary.
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

for tool in cargo pkg-config; do
	command -v "$tool" >/dev/null 2>&1 || {
		echo "error: missing build tool: $tool" >&2
		exit 1
	}
done

if [[ ! -f ${SRC}/Cargo.toml ]]; then
	echo "error: ${SRC}/Cargo.toml is missing" >&2
	exit 1
fi

cd "$SRC"

if [[ ${MODE} == check ]]; then
	cargo test
	exit 0
fi

cargo build --release
[[ -x ${OUT} ]] || {
	echo "error: cargo did not produce ${OUT}" >&2
	exit 1
}

install -Dm755 "$OUT" "$PKG_BIN"
printf 'Built %s\nCopied to %s\n' "$OUT" "$PKG_BIN"
