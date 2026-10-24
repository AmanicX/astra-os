#!/usr/bin/env bash
# Entrypoint redirecting to setup.sh
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
exec bash "${SCRIPT_DIR}/setup.sh" "$@"
