#!/usr/bin/env bash
# Rebrand a copied archiso releng profile for AstraOS.
#
# Usage: rebrand-archiso.sh <profile-dir>
#
# Only user-visible strings are changed. Functional tokens such as
# archisobasedir=, archisosearchuuid=, %INSTALL_DIR%, %ARCH% and the entry
# filenames stay untouched so the generated ISO still boots.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=scripts/lib/brand.sh
source "${SCRIPT_DIR}/lib/brand.sh"

usage() {
	cat <<'EOF'
Usage: rebrand-archiso.sh <profile-dir>

Rebrand the boot menus in an assembled archiso profile.
EOF
}

if (($# != 1)); then
	usage >&2
	exit 2
fi

profile=$1
[[ -d ${profile} ]] || die "profile directory not found: ${profile}"
[[ -d ${profile}/efiboot && -d ${profile}/grub && -d ${profile}/syslinux ]] ||
	die "not an archiso profile: ${profile}"

brand_load

sed_escape() {
	printf '%s' "$1" | sed -e 's/[&|\\]/\\&/g'
}

replace_in_file() {
	local file=$1
	shift
	[[ -f ${file} ]] || return 0
	sed -i "$@" "${file}"
}

name_escaped="$(sed_escape "${BRAND_NAME}")"
id_escaped="$(sed_escape "${BRAND_ID}")"
live_escaped="$(sed_escape "${BRAND_LIVE_NAME}")"

# systemd-boot entries. The file names and the loader.conf default stay as-is;
# they are functional identifiers, not user-visible text.
while IFS= read -r -d '' entry; do
	replace_in_file "${entry}" \
		-e "s|^title[[:space:]]\+.*Arch Linux install medium|title    ${live_escaped}|" \
		-e "s|^title[[:space:]]\+Memtest86[+]\$|title    ${name_escaped} Memtest86+|"
done < <(find "${profile}/efiboot/loader/entries" -type f -name '*.conf' -print0)

# GRUB and GRUB loopback menus.
while IFS= read -r -d '' grub_file; do
	replace_in_file "${grub_file}" \
		-e "s|^default=archlinux\$|default=${id_escaped}|" \
		-e "s|Arch Linux install medium with speakup screen reader|${live_escaped} with speech|g" \
		-e "s|Arch Linux install medium|${live_escaped}|g" \
		-e "s|--class arch |--class ${id_escaped} |g" \
		-e "s|--id 'archlinux-accessibility'|--id '${id_escaped}-accessibility'|g" \
		-e "s|--id 'archlinux'|--id '${id_escaped}'|g" \
		-e "s|Run Memtest86[+]|${name_escaped} Memtest86+|g" \
		-e "s|menuentry 'UEFI Shell'|menuentry '${name_escaped} UEFI Shell'|g"
done < <(find "${profile}/grub" -maxdepth 1 -type f \
	\( -name 'grub.cfg' -o -name 'loopback.cfg' \) -print0)

# AstraOS GRUB Theme on the ISO media
theme_src="${REPO_ROOT}/packages/astra-branding/files/usr/share/grub/themes/astra"
if [[ -d ${theme_src} ]]; then
	mkdir -p "${profile}/grub/themes/astra"
	cp -a "${theme_src}/." "${profile}/grub/themes/astra/"
	if [[ -f "${profile}/grub/grub.cfg" ]]; then
		sed -i 's/terminal_output console/insmod gfxterm\n    insmod png\n    set gfxmode="1920x1080,auto"\n    if [ -f "${prefix}\/themes\/astra\/theme.txt" ]; then\n        set theme="${prefix}\/themes\/astra\/theme.txt"\n    fi\n    terminal_output gfxterm/' "${profile}/grub/grub.cfg"
	fi
fi

# systemd-boot splash on the ISO
splash_src="${REPO_ROOT}/packages/astra-branding/files/usr/share/astra/branding/splash.bmp"
if [[ -f ${splash_src} && -d "${profile}/efiboot/loader" ]]; then
	cp -f "${splash_src}" "${profile}/efiboot/loader/splash.bmp"
	if [[ -f "${profile}/efiboot/loader/loader.conf" ]]; then
		grep -q '^splash' "${profile}/efiboot/loader/loader.conf" ||
			printf 'splash /loader/splash.bmp\n' >>"${profile}/efiboot/loader/loader.conf"
	fi
fi

# syslinux is not in the current UEFI-only build, but keep the profile source
# consistent if a BIOS boot mode is enabled later.
while IFS= read -r -d '' sys_file; do
	replace_in_file "${sys_file}" \
		-e "s|MENU TITLE Arch Linux|MENU TITLE ${name_escaped}|g" \
		-e "s|Boot the Arch Linux install medium|Boot the ${live_escaped} medium|g" \
		-e "s|Boot the Arch Linux live medium|Boot the ${live_escaped} medium|g" \
		-e "s|install Arch Linux|install ${name_escaped}|g" \
		-e "s|Arch Linux install medium|${live_escaped}|g" \
		-e "s|Arch Linux live medium|${live_escaped}|g" \
		-e "s|Run Memtest86[+]|${name_escaped} Memtest86+|g"
done < <(find "${profile}/syslinux" -type f -name '*.cfg' -print0)

# Fail closed if a visible Arch Linux boot title survived. Technical references
# in comments are not checked here; only the menu strings above are replaced.
if grep -RIlE \
	'Arch Linux install medium|MENU TITLE Arch Linux|install Arch Linux|Boot the Arch Linux' \
	"${profile}/efiboot" "${profile}/grub" "${profile}/syslinux" >/dev/null; then
	grep -RInE \
		'Arch Linux install medium|MENU TITLE Arch Linux|install Arch Linux|Boot the Arch Linux' \
		"${profile}/efiboot" "${profile}/grub" "${profile}/syslinux" >&2 || true
	die "archiso profile still contains Arch Linux boot titles"
fi

# ISO identity. The label is a technical uppercase identifier; everything else
# is the mixed-case product name from config/brand.toml.
if [[ -f ${profile}/profiledef.sh ]]; then
	sed -i \
		-e "s|^iso_name=.*|iso_name=\"${BRAND_ID}\"|" \
		-e "s|^iso_label=.*|iso_label=\"${BRAND_ISO_LABEL_PREFIX}_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)\"|" \
		-e "s|^iso_publisher=.*|iso_publisher=\"${BRAND_NAME} <${BRAND_WEBSITE}>\"|" \
		-e "s|^iso_application=.*|iso_application=\"${BRAND_NAME} Live Installer\"|" \
		"${profile}/profiledef.sh"
fi

# Guard the archiso-specific tokens that make the live medium findable.
grep -Rqs 'archisobasedir=' "${profile}/efiboot" "${profile}/grub" ||
	die "rebrand removed archisobasedir= tokens"
grep -Rqs 'archisosearchuuid=' "${profile}/efiboot" "${profile}/grub" ||
	die "rebrand removed archisosearchuuid= tokens"

log "rebranded archiso boot menus for ${BRAND_NAME}"
