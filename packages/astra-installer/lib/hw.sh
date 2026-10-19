# Hardware detection for the installer. Data-driven from lspci -nnk, offline.

# Print "amd" or "intel" based on CPU vendor.
cpu_vendor() {
	local vendor
	vendor="$(awk -F: '/^vendor_id/{ gsub(/^[ \t]+/,"",$2); print $2; exit }' /proc/cpuinfo 2>/dev/null || true)"
	case "$vendor" in
	*"AuthenticAMD"*) printf 'amd' ;;
	*"GenuineIntel"*) printf 'intel' ;;
	*) printf 'amd' ;; # most common fallback
	esac
}

# Print the NVIDIA branch (current, 580xx, or nouveau) for a PCI id, else "nouveau".
nvidia_branch() {
	local pci_id=$1
	case "$pci_id" in
	10de:1eb0 | 10de:1ec0 | 10de:1f01 | 10de:1f82 | 10de:1f90 | 10de:2*) printf 'current' ;;
	10de:13c0 | 10de:13b0 | 10de:13d0 | 10de:1400 | 10de:1180 | 10de:13*) printf '580xx' ;;
	*) printf 'nouveau' ;;
	esac
}

# Select offline driver manifests for this host. Prints one manifest name per line.
select_drivers() {
	local vendor has_nvidia=0 nvidia_pci=""
	vendor="$(cpu_vendor)"

	if command -v lspci >/dev/null 2>&1; then
		if lspci -nn | grep -q -i 'nvidia'; then
			has_nvidia=1
			nvidia_pci="$(lspci -nn | sed -n 's/.*\[\([0-9a-fA-F:]*\)\].*/\1/p' | awk -F: '/^10de/{print $2; exit}')"
		fi
	fi

	local -a sets=()
	case "$vendor" in
	amd) sets+=("drivers-amd") ;;
	intel) sets+=("drivers-intel") ;;
	esac

	if ((has_nvidia == 1)); then
		local branch
		branch="$(nvidia_branch "${nvidia_pci}")"
		sets+=("drivers-nvidia")
	fi

	sets+=("drivers-vm")

	printf '%s\n' "${sets[@]}"
}
