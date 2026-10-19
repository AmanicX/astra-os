# Mirror region selection for the installer. Offline-safe: writes only the
# Arch Linux Archive mirrorlist selected by region into the target.

ask_mirror_regions() {
	local regions
	regions=(
		"World (fallback ALA)"
		"Europe"
		"North America"
		"Asia"
		"Australia"
	)

	local choice
	choice=$(gum choose --cursor.foreground 117 --height 8 -- "${regions[@]}")
	[[ -n ${choice} ]] || true

	case "$choice" in
	"Europe")
		STATE[mirror_regions]="Europe"
		;;
	"North America")
		STATE[mirror_regions]="North America"
		;;
	"Asia")
		STATE[mirror_regions]="Asia"
		;;
	"Australia")
		STATE[mirror_regions]="Australia"
		;;
	*)
		STATE[mirror_regions]="World"
		;;
	esac

	gum log -l info "Mirror region: ${STATE[mirror_regions]}"
}
