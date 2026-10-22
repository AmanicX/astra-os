# Hardware detection for the installer. Data-driven from lspci -nnk, offline.
# This file only records manifest choices; it never writes to a disk.

# Print "amd" or "intel" based on the CPU vendor.
cpu_vendor() {
	local vendor
	vendor="$(awk -F: '/^vendor_id/{ gsub(/^[ \t]+/,"",$2); print $2; exit }' /proc/cpuinfo 2>/dev/null || true)"
	case "$vendor" in
	*"AuthenticAMD"*) printf 'amd' ;;
	*"GenuineIntel"*) printf 'intel' ;;
	*) printf 'unknown' ;;
	esac
}

# True when an AMD/Intel/NVIDIA display controller is present.
has_amd_gpu() {
	command -v lspci >/dev/null 2>&1 || return 1
	lspci -nn 2>/dev/null | grep -Eiq '(VGA compatible controller|3D controller|Display controller).*\[1002:'
}

has_intel_gpu() {
	command -v lspci >/dev/null 2>&1 || return 1
	lspci -nn 2>/dev/null | grep -Eiq '(VGA compatible controller|3D controller|Display controller).*\[8086:'
}

has_nvidia_gpu() {
	command -v lspci >/dev/null 2>&1 || return 1
	lspci -nn 2>/dev/null | grep -Eiq '(VGA compatible controller|3D controller|Display controller).*\[10de:'
}

# Print the NVIDIA branch (current, 580xx, or nouveau) for a PCI id.
# Turing (0x1e00) and newer use the current open branch.  Maxwell, Pascal and
# Volta are serviced by the 580xx branch.  Everything older falls back to
# nouveau.  This is a conservative classification; the package manifests are
# the source of truth for what is actually installed.
nvidia_branch() {
	local pci_id=${1,,}
	case "$pci_id" in
	10de:0* | 10de:1[0-3]*)
		printf '580xx'
		;;
	10de:1[4-9]* | 10de:2* | 10de:3* | 10de:4* | 10de:5*)
		printf 'current'
		;;
	*)
		printf 'nouveau'
		;;
	esac
}

# Print selected driver manifest names, one per line.  The caller resolves
# each name to MANIFESTS_DIR/<name>.txt.
select_drivers() {
	local virt
	local any=0

	if has_amd_gpu; then
		printf 'drivers-amd\n'
		any=1
	fi
	if has_intel_gpu; then
		printf 'drivers-intel\n'
		any=1
	fi
	if has_nvidia_gpu; then
		printf 'drivers-nvidia\n'
		any=1
	fi

	# If lspci is unavailable or reports no display controller, install both
	# open-source stacks.  They are harmless together and cover firmware-only
	# or passthrough setups.
	if ((any == 0)); then
		printf 'drivers-amd\n'
		printf 'drivers-intel\n'
	fi

	virt="$(systemd-detect-virt 2>/dev/null || true)"
	case "$virt" in
	"" | none) ;;
	*) printf 'drivers-vm\n' ;;
	esac
}
