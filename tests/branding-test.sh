#!/usr/bin/env bash
# Static branding checks for Phase 1.
#
# This does not build an ISO. It copies the installed archiso releng profile to
# a temporary directory, runs the same rebrand step as build-iso.sh, and checks
# the resulting menu text and the checked-in wordmark assets.
set -Eeuo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly root
# shellcheck source=scripts/lib/common.sh
source "${root}/scripts/lib/common.sh"
# shellcheck source=scripts/lib/brand.sh
source "${root}/scripts/lib/brand.sh"

releng=${ASTRA_RELENG_PROFILE:-/usr/share/archiso/configs/releng}
[[ -d ${releng} ]] || {
	printf 'skip: archiso releng profile not found at %s\n' "${releng}"
	exit 0
}

brand_load

tmpdir="$(mktemp -d)"
trap 'rm -rf -- "${tmpdir}"' EXIT

cp -a "${releng}/." "${tmpdir}/"
"${root}/scripts/rebrand-archiso.sh" "${tmpdir}" >/dev/null

failures=0

check_no_match() {
	local label=$1 pattern=$2
	if grep -RIlE -- "${pattern}" "${tmpdir}/efiboot" "${tmpdir}/grub" \
		"${tmpdir}/syslinux" >/dev/null; then
		printf 'FAIL: %s\n' "${label}" >&2
		grep -RInE -- "${pattern}" "${tmpdir}/efiboot" "${tmpdir}/grub" \
			"${tmpdir}/syslinux" >&2 || true
		failures=$((failures + 1))
	else
		printf 'ok: %s\n' "${label}"
	fi
}

check_match() {
	local label=$1 pattern=$2 file=$3
	if grep -qE -- "${pattern}" "${file}"; then
		printf 'ok: %s\n' "${label}"
	else
		printf 'FAIL: %s (%s)\n' "${label}" "${file}" >&2
		failures=$((failures + 1))
	fi
}

check_no_match 'no Arch Linux install-medium titles' \
	'Arch Linux install medium|MENU TITLE Arch Linux|install Arch Linux|Boot the Arch Linux'
check_no_match 'no all-caps ASTRAOS in boot menus' 'ASTRAOS'

check_match 'systemd-boot default entry is branded' \
	"title[[:space:]]+${BRAND_LIVE_NAME}" \
	"${tmpdir}/efiboot/loader/entries/01-archiso-linux.conf"
check_match 'systemd-boot speech entry is branded' \
	"title[[:space:]]+${BRAND_LIVE_NAME}.*with speech" \
	"${tmpdir}/efiboot/loader/entries/02-archiso-speech-linux.conf"
check_match 'systemd-boot memtest entry is branded' \
	"title[[:space:]]+${BRAND_NAME} Memtest86" \
	"${tmpdir}/efiboot/loader/entries/03-archiso-memtest86+x64.conf"
check_match 'GRUB default entry is branded' \
	"menuentry \"${BRAND_LIVE_NAME}" "${tmpdir}/grub/grub.cfg"
check_match 'syslinux title is branded' \
	"MENU TITLE ${BRAND_NAME}" "${tmpdir}/syslinux/archiso_head.cfg"
check_match 'ISO name is the lowercase brand id' \
	"iso_name=\"${BRAND_ID}\"" "${tmpdir}/profiledef.sh"
check_match 'ISO publisher is mixed-case AstraOS' \
	"iso_publisher=\"${BRAND_NAME} <${BRAND_WEBSITE}>\"" "${tmpdir}/profiledef.sh"
check_match 'ISO application is mixed-case AstraOS' \
	"iso_application=\"${BRAND_NAME} Live Installer\"" "${tmpdir}/profiledef.sh"
check_match 'ISO label keeps the uppercase technical prefix' \
	"iso_label=\"${BRAND_ISO_LABEL_PREFIX}_[0-9]{6}\"" "${tmpdir}/profiledef.sh"

if grep -Rqs 'archisobasedir=' "${tmpdir}/efiboot" "${tmpdir}/grub" &&
	grep -Rqs 'archisosearchuuid=' "${tmpdir}/efiboot" "${tmpdir}/grub"; then
	printf 'ok: archiso search tokens preserved\n'
else
	printf 'FAIL: archiso search tokens were removed\n' >&2
	failures=$((failures + 1))
fi

wordmark="${root}/packages/astra-branding/files/usr/share/astra/branding/astraos-wordmark.svg"
lockup="${root}/packages/astra-branding/files/usr/share/astra/branding/astraos-lockup.svg"
wallpaper="${root}/packages/astra-branding/files/usr/share/astra/branding/astraos-wallpaper.svg"

if grep -q '>Astra<tspan' "${wordmark}" &&
	! grep -q '>ASTRA<tspan' "${wordmark}"; then
	printf 'ok: wordmark is mixed-case AstraOS\n'
else
	printf 'FAIL: wordmark is not mixed-case AstraOS\n' >&2
	failures=$((failures + 1))
fi

if grep -q '>Astra<tspan' "${lockup}" &&
	! grep -q '>ASTRA<tspan' "${lockup}"; then
	printf 'ok: lockup wordmark is mixed-case AstraOS\n'
else
	printf 'FAIL: lockup wordmark is not mixed-case AstraOS\n' >&2
	failures=$((failures + 1))
fi

if grep -q '>AstraOS</text>' "${wallpaper}" &&
	! grep -q '>ASTRAOS</text>' "${wallpaper}"; then
	printf 'ok: wallpaper caption is mixed-case AstraOS\n'
else
	printf 'FAIL: wallpaper caption is not mixed-case AstraOS\n' >&2
	failures=$((failures + 1))
fi

if ((failures > 0)); then
	printf 'branding-test: FAILED (%s failure(s))\n' "${failures}" >&2
	exit 1
fi

printf 'branding-test: PASS\n'
