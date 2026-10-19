#!/usr/bin/env bash
# Manifest selection helpers. Source after scripts/lib/common.sh.

if [[ -n ${ASTRA_MANIFESTS_SH_LOADED:-} ]]; then
	return 0
fi
ASTRA_MANIFESTS_SH_LOADED=1

MANIFESTS_DIR="${REPO_ROOT}/manifests"
readonly MANIFESTS_DIR

manifest_path() {
	printf '%s/%s\n' "$MANIFESTS_DIR" "$1"
}

# Everything that must exist in the offline repository: every hardware branch,
# guest tools, live-only tools and the Astra packages. The installer chooses a
# subset at install time (D-030).
manifest_repo_all() {
	manifest_union \
		"$(manifest_path base.txt)" \
		"$(manifest_path desktop.txt)" \
		"$(manifest_path apps.txt)" \
		"$(manifest_path drivers-amd.txt)" \
		"$(manifest_path drivers-intel.txt)" \
		"$(manifest_path drivers-nvidia.txt)" \
		"$(manifest_path drivers-vm.txt)" \
		"$(manifest_path fonts-themes.txt)" \
		"$(manifest_path iso.txt)" \
		"$(manifest_path astra.txt)"
}

manifest_aur() {
	manifest_packages "$(manifest_path aur.txt)"
}

manifest_astra() {
	manifest_packages "$(manifest_path astra.txt)"
}

# Official repository packages in the repository payload. AUR and Astra-owned
# names are removed; they are built separately.
manifest_repo_official() {
	local all skip
	all="$(mktemp)"
	skip="$(mktemp)"
	manifest_repo_all >"$all"
	{
		manifest_aur
		manifest_astra
	} | sort -u >"$skip"
	awk 'NR == FNR { skip[$0] = 1; next } !($0 in skip)' "$skip" "$all"
	rm -f -- "$all" "$skip"
}

# Live ISO package set: base + desktop + AMD/Intel open graphics + approved
# apps + fonts + ISO tools + Astra packages, minus target-only packages.
manifest_live() {
	local all exclude
	all="$(mktemp)"
	exclude="$(mktemp)"
	manifest_union \
		"$(manifest_path base.txt)" \
		"$(manifest_path desktop.txt)" \
		"$(manifest_path apps.txt)" \
		"$(manifest_path drivers-amd.txt)" \
		"$(manifest_path drivers-intel.txt)" \
		"$(manifest_path fonts-themes.txt)" \
		"$(manifest_path iso.txt)" \
		"$(manifest_path astra.txt)" >"$all"
	manifest_packages "$(manifest_path live-exclude.txt)" >"$exclude"
	awk 'NR == FNR { skip[$0] = 1; next } !($0 in skip)' "$exclude" "$all"
	rm -f -- "$all" "$exclude"
}

# Packages installed on the target by astra-meta. Hardware drivers are chosen
# by the installer and are not part of this default set.
manifest_target_meta() {
	local all exclude
	all="$(mktemp)"
	exclude="$(mktemp)"
	manifest_union \
		"$(manifest_path base.txt)" \
		"$(manifest_path desktop.txt)" \
		"$(manifest_path apps.txt)" \
		"$(manifest_path fonts-themes.txt)" \
		"$(manifest_path astra.txt)" >"$all"
	manifest_packages "$(manifest_path target-exclude.txt)" >"$exclude"
	awk 'NR == FNR { skip[$0] = 1; next } !($0 in skip)' "$exclude" "$all"
	rm -f -- "$all" "$exclude"
}
