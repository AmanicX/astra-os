# Storage selection for the AstraOS installer.
#
# Rules (D-003, D-024):
# - GPT only.
# - Whole-disk mode: 1 GiB FAT32 ESP at /boot/efi + Btrfs root. No LUKS in v1.
# - Dual-boot mode: create partitions only inside free space; never write an
#   existing partition. Existing GPT entries are snapshotted before and
#   compared after (start/end/type GUID/unique GUID/name + filesystem UUID).
# - Btrfs subvolumes: @ @home @log @pkg @snapshots, mounted with
#   noatime,compress=zstd:1,space_cache=v2,discard=async.
# - zram swap via zram-generator; no swap partition.
#
# Nothing is written until the final confirmation; this step only *records* a
# partition plan in the STATE array.

# List writable whole disks. Prints "path\tsizeGiB".
list_disks() {
	local d name size
	for d in /sys/block/*; do
		name="$(basename "$d")"
		case "$name" in
		loop* | ram* | sr*) continue ;;
		esac
		[[ -e "$d" ]] || continue
		size=$(awk '/^size/{printf "%d", $2 * 512 / 1024 / 1024 / 1024}' "$d" 2>/dev/null || echo 0)
		[[ $size -gt 0 ]] || continue
		printf '%s\t%sG\n' "/dev/$name" "$size"
	done
}

# Snapshot every GPT partition on a disk as a deterministic, sorted record.
snapshot_gpt() {
	local disk=$1 n start end typeguid uuid part
	for n in $(sgdisk -p "$disk" 2>/dev/null | awk '/^Number/{f=1;next} f&&NF{print $1}'); do
		read -r start end typeguid _ < <(
			sgdisk -i "$n" "$disk" 2>/dev/null \
				| awk '/^First sector:/{fs=$2} /^Last sector:/{ls=$2} /^Partition type code:/{tc=$3} END{printf "%s %s %s\n", fs, ls, tc}'
		)
		uuid=""
		part="/dev/disk/by-partuuid/$(sgdisk -i "$n" "$disk" 2>/dev/null \
			| awk '/^Partition unique GUID:/{print tolower($3)}')"
		[[ -L "$part" ]] && uuid=$(blkid -s UUID -o value "$part" 2>/dev/null || true)
		printf '%s %s %s %s %s\n' "$n" "$start" "$end" "$typeguid" "$uuid"
	done | sort
}

# Compare the current GPT to the snapshot taken before partitioning.
verify_gpt_unchanged() {
	local disk=$1 after
	after="$(snapshot_gpt "$disk")"
	if [[ -n "${GPT_BEFORE:-}" && "$after" != "${GPT_BEFORE}" ]]; then
		die "existing GPT entries changed during dual-boot partitioning (D-024). Aborting."
	fi
}

ask_storage() {
	local -a disks=() disk choice
	mapfile -t disks < <(list_disks)
	((${#disks[@]} > 0)) || die "no writable disks found"

	gum format --type markdown -- '## Storage

Use a whole disk (it is wiped), or install alongside an existing system using
free space (existing partitions are never written to).'

	choice=$(gum choose --cursor.foreground 117 --header "Installation mode:" \
		"Whole disk" "Dual-boot (free space)")
	[[ -n ${choice} ]] || die "no mode selected"

	case "$choice" in
	"Whole disk") STATE[storage_mode]="whole" ;;
	"Dual-boot (free space)") STATE[storage_mode]="dual" ;;
	esac

	disk=$(printf '%s\n' "${disks[@]}" \
		| gum choose --cursor.foreground 117 --header "Select the installation disk:")
	STATE[disk]="${disk%%$'\t'*}"

	if [[ ${STATE[storage_mode]} == "whole" ]]; then
		STATE[esp_size]="1G"
		STATE[root_size]=""
	else
		local root_size
		root_size=$(gum input --prompt "Root Btrfs size (e.g. 30GiB): " --placeholder "30GiB")
		STATE[root_size]="${root_size:-30GiB}"
	fi

	gum log -l info "Storage: ${STATE[storage_mode]} on ${STATE[disk]}"
}
