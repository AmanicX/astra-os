#!/usr/bin/env bash
# Read the AstraOS identity from config/brand.toml.
#
# Source this file after scripts/lib/common.sh. Do not execute it directly.
# The parser intentionally supports the simple `key = "value"` form used by
# brand.toml; it is not a general-purpose TOML parser.

if [[ -n ${ASTRA_BRAND_SH_LOADED:-} ]]; then
	return 0
fi
ASTRA_BRAND_SH_LOADED=1

BRAND_FILE="${ASTRA_BRAND_FILE:-${REPO_ROOT}/config/brand.toml}"

brand_value() {
	local key=$1
	local file=${2:-${BRAND_FILE}}

	[[ -r ${file} ]] || return 1

	awk -v key="${key}" '
		/^[[:space:]]*#/ { next }
		$0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
			line = $0
			sub(/^[^=]*=[[:space:]]*/, "", line)
			sub(/[[:space:]]+#.*$/, "", line)
			sub(/^"/, "", line)
			sub(/"$/, "", line)
			print line
			found = 1
			exit
		}
		END { if (!found) exit 1 }
	' "${file}"
}

brand_load() {
	local value

	value="$(brand_value name)" || die "brand.toml: missing name"
	BRAND_NAME="${value}"
	value="$(brand_value long_name)" || die "brand.toml: missing long_name"
	BRAND_LONG_NAME="${value}"
	value="$(brand_value id)" || die "brand.toml: missing id"
	BRAND_ID="${value}"
	value="$(brand_value iso_label_prefix)" ||
		die "brand.toml: missing iso_label_prefix"
	BRAND_ISO_LABEL_PREFIX="${value}"
	value="$(brand_value website)" || die "brand.toml: missing website"
	BRAND_WEBSITE="${value}"
	value="$(brand_value tagline)" || die "brand.toml: missing tagline"
	BRAND_TAGLINE="${value}"

	[[ ${BRAND_NAME} =~ ^[A-Za-z][A-Za-z0-9._-]*$ ]] ||
		die "brand.toml: name must be a single mixed-case token"
	[[ ${BRAND_ID} =~ ^[a-z][a-z0-9._-]*$ ]] ||
		die "brand.toml: id must be a lowercase token"
	[[ ${BRAND_ISO_LABEL_PREFIX} =~ ^[A-Z0-9_]+$ ]] ||
		die "brand.toml: iso_label_prefix must be uppercase"
	[[ -n ${BRAND_LONG_NAME} && -n ${BRAND_WEBSITE} && -n ${BRAND_TAGLINE} ]] ||
		die "brand.toml: long_name, website and tagline must not be empty"

	BRAND_LIVE_NAME="${BRAND_NAME} Live"
	export BRAND_NAME BRAND_LONG_NAME BRAND_ID BRAND_ISO_LABEL_PREFIX
	export BRAND_WEBSITE BRAND_TAGLINE BRAND_LIVE_NAME
}
