# Storage planning and execution.
#
# Safety rules enforced here:
#   * Nothing is written to a disk before the final INSTALL confirmation.
#   * Whole-disk mode requires the user to type ERASE.
#   * Free-space mode only creates partitions inside the exact free region the
#     user selected.  Existing GPT entries are snapshotted first and verified
#     unchanged afterwards.
#   * Manual mode formats only the root partition the user selected.  It never
#     formats the EFI partition.
#   * Pre-mounted mode never partitions, formats, mounts or unmounts anything.
#
# The flow mirrors archinstall's storage menu while making the destructive
# choices more explicit.

# MIN_INSTALL_GIB is the minimum total target capacity promised by the
# installer.  A new ESP is carved out of that capacity, so the root partition
# itself only needs MIN_ROOT_GIB.  Keeping these separate lets a 35 GiB disk
# install successfully (1 GiB ESP + 34 GiB root) while still rejecting a disk
# smaller than the documented 35 GiB total.
MIN_INSTALL_GIB="${ASTRA_MIN_INSTALL_GIB:-35}"
ESP_SIZE_GIB=1
MIN_ROOT_GIB="${ASTRA_MIN_ROOT_GIB:-$((MIN_INSTALL_GIB - ESP_SIZE_GIB))}"
RECOMMENDED_INSTALL_GIB="${ASTRA_RECOMMENDED_INSTALL_GIB:-40}"
# GPT and alignment overhead that must fit in addition to the payload.
DISK_OVERHEAD_MIB=2
GPT_ESP_GUID="C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
GPT_LINUX_GUID="0FC63DAF-8483-4772-8E79-3D69D8477DE4"

part_path() {
	local disk=$1 num=$2
	case "$disk" in
	*[0-9]) printf '%sp%s' "$disk" "$num" ;;
	*) printf '%s%s' "$disk" "$num" ;;
	esac
}

# Wait for the kernel to publish freshly created partition device nodes.  Real
# hardware usually gets there immediately via udev; loop devices and minimal
# live environments can need a few retries.
wait_for_partition() {
	local disk=$1 part=$2 i
	for i in {1..25}; do
		[[ -b $part ]] && return 0
		partprobe "$disk" 2>/dev/null || true
		sleep 0.2
	done
	[[ -b $part ]]
}

# ---------------------------------------------------------------------------
# Disk discovery.
# ---------------------------------------------------------------------------

list_disks() {
	local name type size model
	while read -r name type size model; do
		[[ $type == disk ]] || continue
		case "$name" in
		loop* | ram* | zram* | sr* | dm-* | md* | nbd* | rbd*) continue ;;
		esac
		[[ -n ${name:-} && -n ${size:-} ]] || continue
		printf '/dev/%s\t%s\t%s\n' "$name" "$size" "${model:-unknown}"
	done < <(lsblk -dn -o NAME,TYPE,SIZE,MODEL 2>/dev/null)
}

is_live_disk() {
	local disk=$1 src pk
	src="$(findmnt -n -o SOURCE /run/archiso/bootmnt 2>/dev/null || true)"
	[[ -n ${src:-} ]] || return 1
	src="$(readlink -f "$src" 2>/dev/null || printf '%s' "$src")"
	pk="$(lsblk -no PKNAME "$src" 2>/dev/null | head -n1 || true)"
	[[ -n ${pk:-} && "/dev/${pk}" == "$disk" ]]
}

disk_has_gpt() {
	local ptype
	ptype="$(blkid -o value -s PTTYPE "$1" 2>/dev/null || true)"
	[[ ${ptype:-} == gpt ]]
}

disk_mountpoints() {
	lsblk -ln -o MOUNTPOINTS "$1" 2>/dev/null | sed '/^[[:space:]]*$/d'
}

show_disks() {
	lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS,MODEL 2>/dev/null | gum pager || pause
}

# Pick a real disk.  The live USB is never offered.
choose_disk() {
	local header=$1
	local -a choices=()
	local dev size model line
	while IFS=$'\t' read -r dev size model; do
		[[ -n ${dev:-} ]] || continue
		if is_live_disk "$dev"; then
			continue
		fi
		choices+=("${dev}|${size}|${model}")
	done < <(list_disks)

	((${#choices[@]} > 0)) ||
		die "no usable disks found. Run 'lsblk' to inspect the system."

	local choice
	choice="$(ui_choose "$header" "${choices[@]}")" || return 1
	STATE[disk]="${choice%%|*}"
	local rest="${choice#*|}"
	STATE[disk_size]="${rest%%|*}"
	[[ -b ${STATE[disk]} ]] || die "not a block device: ${STATE[disk]}"
	log "selected disk: ${STATE[disk]} (${STATE[disk_size]})"
}

# ---------------------------------------------------------------------------
# GPT free-space discovery.  Only used in free-space mode.
# ---------------------------------------------------------------------------

print_region() {
	local start=$1 end=$2 mib
	((end >= start)) || return 0
	# GPT sector numbers are 512-byte units regardless of the disk's logical
	# sector size.
	mib=$(((end - start + 1) / 2048))
	((mib >= 1)) || return 0
	printf '%s\t%s\t%s\n' "$start" "$end" "$mib"
}

list_free_regions() {
	local disk=$1 first last
	local -a parts=()
	local -a sorted=()
	local n pstart pend pair s e

	read -r first last < <(
		sgdisk -p "$disk" 2>/dev/null |
			sed -n 's/^First usable sector is \([0-9]*\), last usable sector is \([0-9]*\).*/\1 \2/p'
	)
	[[ -n ${first:-} && -n ${last:-} ]] || return 1

	while read -r n pstart pend; do
		[[ $n =~ ^[0-9]+$ ]] || continue
		parts+=("${pstart}:${pend}")
	done < <(sgdisk -p "$disk" 2>/dev/null |
		awk '/^Number/{f=1;next} f && $1 ~ /^[0-9]+$/ {print $1, $2, $3}')

	if ((${#parts[@]} > 0)); then
		mapfile -t sorted < <(printf '%s\n' "${parts[@]}" | sort -t: -k1,1n)
	fi

	local cursor=$first
	for pair in "${sorted[@]}"; do
		s="${pair%%:*}"
		e="${pair##*:}"
		if ((s > cursor)); then
			print_region "$cursor" "$((s - 1))"
		fi
		((e >= cursor)) && cursor=$((e + 1))
	done
	if ((cursor <= last)); then
		print_region "$cursor" "$last"
	fi
}

choose_free_region() {
	local min_mib=$1
	local -a all=()
	local -a usable=()
	local start end mib label
	while IFS=$'\t' read -r start end mib; do
		[[ -n ${start:-} ]] || continue
		label="${start}|${end}|${mib}|$(awk -v m="$mib" 'BEGIN{printf "%.1f GiB", m/1024}')"
		all+=("$label")
		((mib >= min_mib)) && usable+=("$label")
	done < <(list_free_regions "${STATE[disk]}")

	((${#all[@]} > 0)) || return 1
	if ((${#usable[@]} == 0)); then
		printf '\nFree space found, but none of it is large enough (%s MiB required):\n' "$min_mib" >&2
		printf '  %s\n' "${all[@]}" >&2
		return 2
	fi

	local choice
	choice="$(ui_choose "Select the free space to install into" "${usable[@]}")" || return 1
	STATE[free_start]="${choice%%|*}"
	local rest="${choice#*|}"
	STATE[free_end]="${rest%%|*}"
	rest="${rest#*|}"
	STATE[free_mib]="${rest%%|*}"
	# Keep the human-readable size for the review screen.
	STATE[free_size]="${rest#*|}"
	log "selected free space: ${STATE[free_start]}-${STATE[free_end]} sectors on ${STATE[disk]} (${STATE[free_size]}, ${STATE[free_mib]} MiB)"
}

# ---------------------------------------------------------------------------
# ESP discovery.
# ---------------------------------------------------------------------------

list_esp_partitions() {
	local d n dev fstype
	local -A seen=()

	# Only real EFI system partitions (GPT type EF00) are candidates.  A random
	# vfat data partition is not an ESP and must never be offered as one.
	while read -r d; do
		[[ -n ${d:-} ]] || continue
		while read -r n; do
			[[ $n =~ ^[0-9]+$ ]] || continue
			[[ $(partition_code "$d" "$n") == EF00 ]] || continue
			dev="$(part_path "$d" "$n")"
			[[ -z ${seen[$dev]:-} ]] || continue
			seen[$dev]=1
			fstype="$(blkid -s TYPE -o value "$dev" 2>/dev/null || true)"
			[[ ${fstype:-} == vfat ]] || continue
			printf '%s\t%s\n' "$dev" "$fstype"
		done < <(sgdisk -p "$d" 2>/dev/null |
			awk '/^Number/{f=1;next} f && $1 ~ /^[0-9]+$/ {print $1}')
	done < <(list_disks | cut -f1)
}

existing_esp_choices() {
	local part fstype parent
	while IFS=$'\t' read -r part fstype; do
		[[ -n ${part:-} ]] || continue
		parent="$(lsblk -no PKNAME "$part" 2>/dev/null | head -n1 || true)"
		if [[ -n ${parent:-} ]] && is_live_disk "/dev/${parent}"; then
			continue
		fi
		printf '%s|%s|%s\n' "$part" "$fstype" "${part##*/}"
	done < <(list_esp_partitions)
}

choose_esp() {
	local allow_new=$1
	local -a entries=()
	local part fstype name line
	while IFS= read -r line; do
		[[ -n ${line:-} ]] || continue
		entries+=("$line")
	done < <(existing_esp_choices)

	local -a choices=()
	if ((allow_new == 1)); then
		choices+=("__new__|new|Create a new 1 GiB ESP in the selected free space (recommended)")
	fi
	for line in "${entries[@]}"; do
		part="${line%%|*}"
		local rest="${line#*|}"
		fstype="${rest%%|*}"
		name="${rest#*|}"
		choices+=("${part}|${fstype}|Use existing ESP ${part} (${fstype}, ${name}) • NOT formatted")
	done

	if ((${#choices[@]} == 0)); then
		# 2 means "nothing to choose"; 1 is reserved for an explicit cancel.
		return 2
	fi

	local choice
	choice="$(ui_choose "EFI system partition" "${choices[@]}")" || return 1
	part="${choice%%|*}"
	if [[ $part == __new__ ]]; then
		STATE[esp_mode]="new"
		STATE[esp_part]=""
		STATE[format_esp]="yes"
		log "will create a new ESP inside the selected free space"
	else
		STATE[esp_mode]="existing"
		STATE[esp_part]="$part"
		STATE[format_esp]="no"
		log "will reuse existing ESP: $part (not formatted)"
	fi
}

# ---------------------------------------------------------------------------
# cfdisk helper.  The user saves changes in cfdisk themselves; the installer
# only reads the resulting table until the final confirmation.
# ---------------------------------------------------------------------------

run_cfdisk() {
	local disk=$1
	command -v cfdisk >/dev/null 2>&1 ||
		die "cfdisk is missing (util-linux is required)"

	ui_markdown "## cfdisk: \`${disk}\`

cfdisk is a **manual** partition editor. Nothing changes until you choose
**Write** and confirm inside cfdisk. If you only want to look, quit without
writing.

Delete an *unused* partition to create free space, or create partitions for
manual mode. Do not delete a partition that belongs to an operating system you
want to keep." || true
	ui_confirm "Open cfdisk on ${disk} now?" || return 1
	if ! cfdisk "$disk"; then
		warn "cfdisk exited with an error; no partition-table change was assumed"
		return 1
	fi
	udevadm settle 2>/dev/null || true
	partprobe "$disk" 2>/dev/null || true
	return 0
}

backup_gpt() {
	local disk=$1 file
	file="${STATE_DIR}/gpt-backup-$(basename "$disk").bin"
	if sgdisk --backup="$file" "$disk" >/dev/null 2>&1; then
		log "GPT backup written to ${file}"
	else
		warn "could not back up the GPT of ${disk}"
	fi
}

# Read the four-character GPT type code (for example EF00) for one partition.
partition_code() {
	local disk=$1 num=$2
	sgdisk -p "$disk" 2>/dev/null |
		awk -v n="$num" '
			/^Number/ { f = 1; next }
			f && $1 == n {
				for (i = 2; i <= NF; i++) {
					if ($i ~ /^[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$/) {
						print $i
						exit
					}
				}
			}
		'
}

# Hash the first MiB of a partition.  This is the content check that makes the
# free-space path stronger than comparing metadata only.  A small temporary
# file keeps a failed read from silently hashing an empty stream.
first_mib_hash() {
	local part=$1 tmp hash
	[[ -b $part ]] || {
		printf 'missing'
		return 0
	}
	tmp="$(mktemp "${STATE_DIR}/first-mib.XXXXXX")" || {
		printf 'unreadable'
		return 0
	}
	if dd if="$part" of="$tmp" bs=1M count=1 status=none 2>/dev/null; then
		hash="$(sha256sum "$tmp" 2>/dev/null | awk '{print $1}')"
	else
		hash="unreadable"
	fi
	rm -f "$tmp"
	printf '%s' "${hash:-unreadable}"
}

# Snapshot every GPT entry, including start/size/type/unique GUID, filesystem
# UUID, partition name, and a hash of the first MiB.  Existing partitions are
# compared against this record after the new partitions have been created.
snapshot_gpt() {
	local disk=$1 n start end info type_guid code uuid fs hash name part size
	sgdisk -p "$disk" >/dev/null 2>&1 || return 0
	while read -r n start end; do
		[[ $n =~ ^[0-9]+$ ]] || continue
		part="$(part_path "$disk" "$n")"
		info="$(sgdisk -i "$n" "$disk" 2>/dev/null || true)"
		type_guid="$(awk '/^Partition GUID code:/{print $4; exit}' <<<"$info")"
		uuid="$(awk '/^Partition unique GUID:/{print $4; exit}' <<<"$info")"
		name="$(sed -n "s/^Partition name: '\(.*\)'\$/\1/p" <<<"$info")"
		code="$(partition_code "$disk" "$n")"
		size=$((end - start + 1))
		fs="$(blkid -s UUID -o value "$part" 2>/dev/null || true)"
		hash="$(first_mib_hash "$part")"
		name="${name//|//}"
		printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
			"$n" "$start" "$end" "$size" "$type_guid" "$code" "$uuid" "$fs" "$hash" "$name"
	done < <(sgdisk -p "$disk" 2>/dev/null |
		awk '/^Number/{f=1;next} f && $1 ~ /^[0-9]+$/ {print $1, $2, $3}')
}

verify_gpt_unchanged() {
	local disk=$1 baseline=$2 after line
	[[ -r $baseline ]] || die "missing GPT baseline for ${disk}"
	after="$(snapshot_gpt "$disk")" || die "could not read the partition table of ${disk}"
	while IFS= read -r line; do
		[[ -n ${line:-} ]] || continue
		if ! grep -Fqx -- "$line" <<<"$after"; then
			die "existing partition changed unexpectedly on ${disk}: ${line}. Refusing to continue."
		fi
	done <"$baseline"
	log "verified that every existing GPT entry and first-MiB hash on ${disk} is unchanged"
}

gpt_line_desc() {
	local line=$1 n start end size type_guid code uuid fs hash name
	IFS='|' read -r n start end size type_guid code uuid fs hash name <<<"$line"
	printf 'partition %s: sectors %s-%s (%s), code %s, fs %s, name %s' \
		"${n:-?}" "${start:-?}" "${end:-?}" "${size:-?}" \
		"${code:-?}" "${fs:-none}" "${name:-none}"
}

# Show what the user changed in cfdisk before any installer-created partition
# exists.  This is deliberately displayed before the free-space choice.
show_gpt_diff() {
	local before=$1 after=$2 disk=$3
	local -A old=() new=()
	local -a old_order=() new_order=()
	local line n deleted=0 unchanged=0 modified=0 added=0 out=""
	while IFS= read -r line; do
		[[ -n ${line:-} ]] || continue
		n="${line%%|*}"
		old["$n"]="$line"
		old_order+=("$n")
	done <"$before"
	while IFS= read -r line; do
		[[ -n ${line:-} ]] || continue
		n="${line%%|*}"
		new["$n"]="$line"
		new_order+=("$n")
	done <"$after"

	for n in "${old_order[@]}"; do
		if [[ -z ${new[$n]:-} ]]; then
			out+="DELETED   $(gpt_line_desc "${old[$n]}")"$'\n'
			deleted=$((deleted + 1))
		elif [[ ${old[$n]} == "${new[$n]}" ]]; then
			out+="UNCHANGED $(gpt_line_desc "${old[$n]}")"$'\n'
			unchanged=$((unchanged + 1))
		else
			out+="MODIFIED  $(gpt_line_desc "${new[$n]}")"$'\n'
			modified=$((modified + 1))
		fi
	done
	for n in "${new_order[@]}"; do
		if [[ -z ${old[$n]:-} ]]; then
			out+="NEW       $(gpt_line_desc "${new[$n]}")"$'\n'
			added=$((added + 1))
		fi
	done

	printf 'GPT changes on %s: %s deleted, %s unchanged, %s modified, %s new\n\n' \
		"$disk" "$deleted" "$unchanged" "$modified" "$added"
	printf '%s' "$out"
	if ((INTERACTIVE == 1)); then
		printf '\nPress Enter after reviewing these changes...'
		read -r _ || true
	fi
	log "cfdisk diff on ${disk}: deleted=${deleted} unchanged=${unchanged} modified=${modified} new=${added}"
}

# Verify a partition the installer just created.  The expected type GUID is
# checked, the requested geometry is enforced, and the partition must live
# entirely inside the selected free region.
verify_new_partition() {
	local disk=$1 num=$2 region_start=$3 region_end=$4 expected_guid=$5 min_mib=$6
	local info start end size guid uuid mib
	info="$(sgdisk -i "$num" "$disk" 2>/dev/null || true)"
	start="$(awk '/^First sector:/{print $3; exit}' <<<"$info")"
	end="$(awk '/^Last sector:/{print $3; exit}' <<<"$info")"
	guid="$(awk '/^Partition GUID code:/{print $4; exit}' <<<"$info")"
	uuid="$(awk '/^Partition unique GUID:/{print $4; exit}' <<<"$info")"
	size="$(awk '/^Partition size:/{print $3; exit}' <<<"$info")"

	[[ $start =~ ^[0-9]+$ && $end =~ ^[0-9]+$ && $size =~ ^[0-9]+$ ]] ||
		die "could not read the geometry of new partition ${num} on ${disk}"
	((start >= region_start && end <= region_end)) ||
		die "new partition ${num} on ${disk} is outside the selected free region"
	[[ ${guid^^} == "${expected_guid^^}" ]] ||
		die "new partition ${num} on ${disk} has type GUID ${guid}, expected ${expected_guid}"
	[[ -n ${uuid:-} ]] || die "new partition ${num} on ${disk} has no unique GUID"

	# sgdisk reports GPT sector counts in 512-byte units.
	mib=$((size / 2048))
	((mib >= min_mib)) ||
		die "new partition ${num} on ${disk} is only ${mib} MiB; ${min_mib} MiB required"
	log "verified new partition ${num} on ${disk}: start=${start} end=${end} size=${mib}MiB type=${guid}"
}

verify_filesystem() {
	local part=$1 expected=$2 type uuid
	type="$(blkid -s TYPE -o value "$part" 2>/dev/null || true)"
	uuid="$(blkid -s UUID -o value "$part" 2>/dev/null || true)"
	[[ ${type:-} == "$expected" ]] ||
		die "${part} was formatted as '${type:-unknown}', expected ${expected}"
	[[ -n ${uuid:-} ]] || die "${part} has no filesystem UUID after formatting"
	log "verified filesystem on ${part}: ${type}, UUID ${uuid}"
}

next_partition_number() {
	local disk=$1 max
	max="$(sgdisk -p "$disk" 2>/dev/null |
		awk '/^Number/{f=1;next} f && $1 ~ /^[0-9]+$/ {if ($1>m) m=$1} END{print m+0}')"
	printf '%s' "$((max + 1))"
}

# ---------------------------------------------------------------------------
# Storage menus.
# ---------------------------------------------------------------------------

whole_disk_setup() {
	choose_disk "Select the disk to erase" || return 1
	show_disks
	local sectors min_sectors
	sectors="$(blockdev --getsz "${STATE[disk]}" 2>/dev/null || printf '0')"
	min_sectors=$((MIN_INSTALL_GIB * 1024))
	min_sectors=$((min_sectors * 2048))
	if [[ ! $sectors =~ ^[0-9]+$ ]] || ((sectors < min_sectors)); then
		ui_markdown "### Disk is too small

\`${STATE[disk]}\` (${STATE[disk_size]}) is smaller than the ${MIN_INSTALL_GIB} GiB
minimum. The installer needs room for a ${ESP_SIZE_GIB} GiB ESP plus the root
filesystem. Choose a larger disk; nothing has been changed." || true
		return 1
	fi

	ui_markdown "## WARNING: whole-disk erase

You selected \`${STATE[disk]}\` (${STATE[disk_size]}).

This deletes **every partition and every file** on that disk. There is no undo.
If you want to keep another operating system, go back and choose free-space
installation instead." || die "could not show the erase warning"

	ui_confirm "Erase the ENTIRE disk ${STATE[disk]}?" || return 1
	local answer
	answer="$(ui_input "Type ERASE to confirm the whole-disk erase" "ERASE")" ||
		return 1
	if [[ $answer != "ERASE" ]]; then
		warn "whole-disk erase was not confirmed"
		return 1
	fi

	STATE[storage_mode]="whole"
	STATE[esp_mode]="new"
	STATE[format_root]="yes"
	STATE[format_esp]="yes"
	STATE[root_part]=""
	STATE[esp_part]=""
	STATE[esp_mount]="/boot/efi"
	STATE[storage_note]="ERASE ENTIRE DISK ${STATE[disk]}"
	log "planned whole-disk install on ${STATE[disk]}"
}

free_space_setup() {
	choose_disk "Select the disk that contains the free space" || return 1
	disk_has_gpt "${STATE[disk]}" ||
		die "${STATE[disk]} is not a GPT disk. Free-space mode requires GPT. Use whole-disk mode, or convert the disk manually."
	(($(disk_mountpoints "${STATE[disk]}" | wc -l) == 0)) ||
		die "partitions on ${STATE[disk]} are mounted. Unmount them first, then run the installer again."

	local disk=${STATE[disk]}
	local original post min_mib rc
	original="${STATE_DIR}/gpt-original-$(basename "$disk").txt"
	backup_gpt "$disk"
	snapshot_gpt "$disk" >"$original" ||
		die "could not snapshot the original partition table of ${disk}"

	while true; do
		run_cfdisk "$disk" || return 1

		post="${STATE_DIR}/gpt-post-cfdisk-$(basename "$disk").txt"
		snapshot_gpt "$disk" >"$post" ||
			die "could not snapshot the partition table after cfdisk"
		show_gpt_diff "$original" "$post" "$disk"

		choose_esp 1 || return 1

		if [[ ${STATE[esp_mode]} == new ]]; then
			min_mib=$(((MIN_ROOT_GIB + ESP_SIZE_GIB) * 1024))
		else
			min_mib=$((MIN_ROOT_GIB * 1024))
		fi
		choose_free_region "$min_mib"
		rc=$?
		case $rc in
		0) break ;;
		1) return 1 ;;
		2)
			ui_markdown "### No free space large enough

The selected disk needs at least **$((min_mib / 1024)) GiB** of contiguous free
space for this layout. Open cfdisk again, delete an unused partition, and write
the table." || true
			ui_confirm "Open cfdisk again?" || return 1
			;;
		*)
			die "could not read free space on ${disk}"
			;;
		esac
	done

	if [[ ${STATE[free_mib]:-0} =~ ^[0-9]+$ ]] && ((STATE[free_mib] < RECOMMENDED_INSTALL_GIB * 1024)); then
		warn "the selected free region is only ${STATE[free_size]}; ${RECOMMENDED_INSTALL_GIB} GiB or more is recommended"
		ui_confirm "${STATE[free_size]} is below the recommended ${RECOMMENDED_INSTALL_GIB} GiB. Continue anyway?" || return 1
	fi

	ui_markdown "## Proposed free-space layout

- Disk: \`${disk}\`
- Free region: sectors **${STATE[free_start]}–${STATE[free_end]}** (${STATE[free_size]})
- Root: new Btrfs partition inside that region
- EFI: $(if [[ ${STATE[esp_mode]} == new ]]; then printf 'new 1 GiB ESP inside that region'; else printf 'existing %s (not formatted)' "${STATE[esp_part]}"; fi)

**No existing partition outside this free region will be touched.**" || true

	ui_confirm "Create the new partitions inside the selected free space?" || return 1

	STATE[storage_mode]="free"
	STATE[format_root]="yes"
	STATE[root_part]=""
	STATE[esp_mount]="/boot/efi"
	STATE[storage_note]="Install into free space on ${disk} (${STATE[free_start]}-${STATE[free_end]})"

	# This is the post-cfdisk baseline.  It intentionally includes changes the
	# user just made in cfdisk; from this point on, the installer must not change
	# any of those entries.
	GPT_BASELINE_FILE="${STATE_DIR}/gpt-baseline-$(basename "$disk").txt"
	cp -f "$post" "$GPT_BASELINE_FILE" ||
		die "could not save the GPT baseline for ${disk}"
	log "saved post-cfdisk GPT baseline to ${GPT_BASELINE_FILE}"
}

manual_setup() {
	choose_disk "Select the disk you partitioned" || return 1
	disk_has_gpt "${STATE[disk]}" ||
		die "${STATE[disk]} is not a GPT disk. Manual UEFI mode requires GPT."
	(($(disk_mountpoints "${STATE[disk]}" | wc -l) == 0)) ||
		die "partitions on ${STATE[disk]} are mounted. Unmount them first."

	backup_gpt "${STATE[disk]}"
	if ui_confirm "Open cfdisk to review or change the partition table?"; then
		run_cfdisk "${STATE[disk]}" || return 1
	fi

	local -a roots=()
	local line part size fstype
	while IFS= read -r line; do
		[[ -n ${line:-} ]] || continue
		roots+=("$line")
	done < <(
		lsblk -J -o NAME,SIZE,FSTYPE,TYPE "${STATE[disk]}" |
			jq -r --arg d "$(basename "${STATE[disk]}")" '
				.blockdevices[] | select(.name==$d) | .children[]? |
				select(.type=="part") |
				"/dev/\(.name)|\(.size)|\(.fstype // "unknown")"'
	)
	((${#roots[@]} > 0)) ||
		die "no partitions found on ${STATE[disk]}. Create them in cfdisk first."

	local root_choice root_fstype
	root_choice="$(ui_choose "Select the ROOT partition (it will be formatted)" "${roots[@]}")" ||
		return 1
	part="${root_choice%%|*}"
	root_fstype="${root_choice#*|}"
	root_fstype="${root_fstype%%|*}"
	[[ -b $part ]] || die "not a block device: ${part}"
	[[ ${root_fstype:-unknown} != vfat ]] ||
		die "${part} is a FAT/vfat partition. Select a Linux root partition instead."

	local root_bytes
	root_bytes="$(blockdev --getsize64 "$part" 2>/dev/null || printf '0')"
	if [[ ! $root_bytes =~ ^[0-9]+$ ]] ||
		((root_bytes < MIN_ROOT_GIB * 1024 * 1024 * 1024)); then
		ui_markdown "### Root partition is too small

\`${part}\` must hold at least **${MIN_ROOT_GIB} GiB**. Choose a larger
partition; nothing has been formatted." || true
		return 1
	fi

	ui_markdown "## Format warning

The selected root partition is \`${part}\`. It will be formatted as Btrfs and
**all data on it will be lost**." || true
	local answer
	answer="$(ui_input "Type FORMAT to confirm formatting ${part}" "FORMAT")" ||
		return 1
	if [[ $answer != "FORMAT" ]]; then
		warn "root formatting was not confirmed"
		return 1
	fi
	STATE[root_part]="$part"

	# Manual mode requires an existing EFI partition.  If none exists, send the
	# user back to cfdisk to create one and try again.  A genuine Esc returns 1
	# and goes back to the storage menu.
	local rc
	while true; do
		choose_esp 0
		rc=$?
		((rc == 0)) && break
		((rc == 2)) || return 1
		ui_markdown "### No EFI system partition found

Manual installation needs an existing EFI system partition (type **EF00**).
Create one in cfdisk, write the table, then choose it here." || true
		ui_confirm "Open cfdisk to create an EFI partition?" || return 1
		run_cfdisk "${STATE[disk]}" || return 1
	done

	[[ ${STATE[esp_part]} != "${STATE[root_part]}" ]] ||
		die "the root and EFI partitions cannot be the same partition"

	local esp_mount
	esp_mount="$(findmnt -n -S "${STATE[esp_part]}" -o TARGET 2>/dev/null | head -n1 || true)"
	if [[ -n ${esp_mount:-} ]]; then
		die "the EFI partition ${STATE[esp_part]} is already mounted at ${esp_mount}. Unmount it, then run the installer again."
	fi

	STATE[storage_mode]="manual"
	STATE[format_root]="yes"
	STATE[format_esp]="no"
	STATE[esp_mount]="/boot/efi"
	STATE[storage_note]="Format root ${STATE[root_part]}, keep ESP ${STATE[esp_part]}"

	ui_confirm "Install with these partitions?" || return 1
	log "planned manual install: root=${STATE[root_part]} esp=${STATE[esp_part]}"
	return 0
}

premounted_setup() {
	local root input
	while true; do
		input="$(ui_input "Root mountpoint (mount root + ESP first, then type /mnt)" "/mnt" "${STATE[premounted_root]:-/mnt}")" ||
			return 1
		if [[ $input == "/" ]]; then
			ui_markdown 'Refusing `/` as the pre-mounted root. That is the live installer environment, not a target filesystem. Mount the target root at `/mnt` and enter `/mnt`.' || true
			continue
		fi
		root="${input%/}"
		[[ -n $root ]] || root="/mnt"
		if [[ $root == "/" ]]; then
			ui_markdown 'Refusing `/` as the pre-mounted root. That is the live installer environment, not a target filesystem. Mount the target root at `/mnt` and enter `/mnt`.' || true
			continue
		fi
		[[ $root == /* ]] || {
			ui_markdown 'The root mountpoint must be an absolute path, normally `/mnt`.' || true
			continue
		}

		if mountpoint -q "$root"; then
			break
		fi

		ui_markdown "## Pre-mounted installation

Mount your root filesystem at \`${root}\` and your EFI system partition at
\`${root}/boot/efi\` **or** directly at \`${root}/boot\`. Then type \`${root}\`
here. In most cases you mount both first and simply enter \`/mnt\`.

\`\`\`
mount /dev/nvme0n1p2 ${root}
mount /dev/nvme0n1p1 ${root}/boot      # or ${root}/boot/efi
\`\`\`

The installer detects the ESP automatically. Use btrfs subvolumes exactly as
you want them: this mode will **not** partition, format, mount or unmount
anything." || true
		if ui_confirm "Open a shell to set up the mounts?"; then
			bash || true
		else
			return 1
		fi
	done

	local candidate fstype source esp_target="" esp_source=""
	for candidate in "$root/boot/efi" "$root/boot" "$root/efi"; do
		mountpoint -q "$candidate" || continue
		fstype="$(findmnt -n -o FSTYPE "$candidate" 2>/dev/null || true)"
		[[ ${fstype:-} == vfat ]] || continue
		esp_target="$candidate"
		esp_source="$(findmnt -n -o SOURCE "$candidate" 2>/dev/null || true)"
		break
	done

	if [[ -z $esp_target ]]; then
		findmnt -R -n -o TARGET,FSTYPE,SOURCE "$root" 2>/dev/null | gum pager || true
		die "no vfat EFI partition mounted at ${root}/boot/efi, ${root}/boot, or ${root}/efi. Mount the ESP there, then run the installer again."
	fi

	local root_source
	root_source="$(findmnt -n -o SOURCE "$root" 2>/dev/null || true)"
	[[ -n ${root_source:-} ]] || die "could not determine the root device under ${root}"
	[[ ${root_source} != "${esp_source}" ]] ||
		die "the root and EFI mounts under ${root} are the same device (${root_source}). Mount a separate ESP."

	local free_mib
	free_mib="$(df -Pm "$root" 2>/dev/null | awk 'NR==2{print $4}')"
	if [[ ${free_mib:-0} =~ ^[0-9]+$ ]] && ((free_mib < 10240)); then
		warn "only ${free_mib} MiB free on ${root}; the desktop install may not fit"
		ui_confirm "Continue anyway?" || return 1
	fi

	ui_markdown "## Pre-mounted configuration

- Root: \`${root_source}\` at \`${root}\`
- EFI: \`${esp_source}\` at \`${esp_target}\`
- EFI mount inside target: \`${esp_target#"$root"}\`

The installer will install packages into these mounts and will **not**
partition, format, mount or unmount anything." || true
	ui_confirm "Use this pre-mounted layout?" || return 1

	STATE[storage_mode]="premounted"
	STATE[premounted_root]="$root"
	STATE[premounted_esp]="$esp_target"
	STATE[root_part]="$root_source"
	STATE[esp_part]="$esp_source"
	STATE[esp_mount]="${esp_target#"$root"}"
	[[ -n ${STATE[esp_mount]} ]] || STATE[esp_mount]="/boot/efi"
	STATE[format_root]="no"
	STATE[format_esp]="no"
	STATE[esp_mode]="premounted"
	STATE[storage_note]="Pre-mounted at ${root}; nothing formatted"
	KEEP_MOUNTS=1
	log "pre-mounted install: root=${root_source} at ${root}, esp=${esp_source} at ${esp_target}"
	return 0
}

ask_storage() {
	local mode
	while true; do
		step_header "Storage"
		ui_markdown '## Storage

Choose how AstraOS should use your disks:

- **Erase a whole disk** — deletes every partition on the selected disk. Requires typing `ERASE`.
- **Install into free space** — keeps existing systems. Opens `cfdisk` so you can free space, then installs only inside the gap you select.
- **Manual partitioning** — create partitions in `cfdisk`, then choose the root and EFI partitions.
- **Use a pre-mounted system** — you already mounted root and EFI; the installer touches neither partitions nor filesystems.

Nothing is written to a partition table until the final `INSTALL` confirmation,
except changes you make yourself inside `cfdisk`.' || die "could not show storage help"

		mode="$(ui_choose "Storage setup" \
			"Erase a whole disk (destructive)" \
			"Install into free space (keep existing OS)" \
			"Manual partitioning (cfdisk)" \
			"Use a pre-mounted system" \
			"Show disks")" || return 1

		case "$mode" in
		Erase*)
			whole_disk_setup && return 0
			;;
		Install*)
			free_space_setup && return 0
			;;
		Manual*)
			manual_setup && return 0
			;;
		Use*)
			premounted_setup && return 0
			;;
		Show*)
			show_disks
			;;
		*)
			return 1
			;;
		esac
	done
}

storage_summary() {
	case "${STATE[storage_mode]}" in
	whole)
		printf -- '- **Erased:** every partition and every file on `%s` (%s)\n' \
			"${STATE[disk]}" "${STATE[disk_size]}"
		printf -- '- **Created:** a new 1 GiB FAT32 ESP and a new Btrfs root\n'
		printf -- '- **Kept:** nothing on that disk\n'
		;;
	free)
		printf -- '- Disk `%s`: install into free space sectors %s–%s (%s)\n' \
			"${STATE[disk]}" "${STATE[free_start]}" "${STATE[free_end]}" "${STATE[free_size]}"
		printf -- '- **Kept:** every existing partition outside that free region%s\n' \
			"$(if [[ ${STATE[esp_mode]} == existing ]]; then printf ' (including ESP `%s`)' "${STATE[esp_part]}"; fi)"
		printf -- '- **Created:** a new Btrfs root inside the gap%s\n' \
			"$(if [[ ${STATE[esp_mode]} == new ]]; then printf ' and a new 1 GiB ESP'; fi)"
		printf -- '- **Erased by the installer:** nothing. Any partition you deleted in cfdisk was already erased by you.\n'
		;;
	manual)
		printf -- '- **Erased:** the previous contents of root partition `%s` (new Btrfs filesystem)\n' \
			"${STATE[root_part]}"
		printf -- '- **Kept:** ESP `%s` (not formatted) and every other partition\n' "${STATE[esp_part]}"
		printf -- '- **Created:** a new Btrfs filesystem on the selected root partition\n'
		;;
	premounted)
		printf -- '- Pre-mounted root at `%s`\n' "${STATE[premounted_root]}"
		printf -- '- Pre-mounted EFI at `%s`\n' "${STATE[premounted_esp]}"
		printf -- '- **Kept:** existing partitions and filesystems; nothing is repartitioned\n'
		printf -- '- **Created:** nothing\n'
		printf -- '- **Erased:** nothing\n'
		;;
	*)
		printf -- '- Storage not selected\n'
		;;
	esac
}

# ---------------------------------------------------------------------------
# Execution.  Called only after the final confirmation.
# ---------------------------------------------------------------------------

prepare_storage() {
	case "${STATE[storage_mode]}" in
	whole) prepare_whole_disk ;;
	free) prepare_free_space ;;
	manual) prepare_manual ;;
	premounted) prepare_premounted ;;
	*) die "internal error: no storage mode selected" ;;
	esac
	mount_target
}

prepare_whole_disk() {
	local disk=${STATE[disk]}
	local mp
	log "WIPING whole disk ${disk}"

	while read -r mp; do
		[[ -n ${mp:-} ]] || continue
		umount -R "$mp" 2>/dev/null || warn "could not unmount ${mp}"
	done < <(disk_mountpoints "$disk")

	sgdisk --zap-all "$disk" >/dev/null 2>&1 ||
		die "could not clear the partition table on ${disk}"
	sgdisk -o "$disk" >/dev/null 2>&1 ||
		die "could not create a GPT on ${disk}"

	sgdisk -n "1:0:+1G" -t "1:EF00" -c "1:EFI system partition" "$disk" >/dev/null ||
		die "could not create the EFI partition on ${disk}"
	sgdisk -n "2:0:0" -t "2:8300" -c "2:AstraOS root" "$disk" >/dev/null ||
		die "could not create the root partition on ${disk}"

	partprobe "$disk" 2>/dev/null || true
	udevadm settle 2>/dev/null || true

	ESP_PART="$(part_path "$disk" 1)"
	ROOT_PART="$(part_path "$disk" 2)"
	wait_for_partition "$disk" "$ESP_PART" ||
		die "the new EFI partition did not appear on ${disk}"
	wait_for_partition "$disk" "$ROOT_PART" ||
		die "the new root partition did not appear on ${disk}"

	local sectors
	sectors="$(blockdev --getsz "$disk" 2>/dev/null || printf '0')"
	if [[ ! $sectors =~ ^[0-9]+$ ]] || ((sectors <= 0)); then
		die "could not read the size of ${disk}"
	fi
	verify_new_partition "$disk" 1 0 "$((sectors - 1))" "$GPT_ESP_GUID" 1024
	verify_new_partition "$disk" 2 0 "$((sectors - 1))" "$GPT_LINUX_GUID" \
		"$((MIN_ROOT_GIB * 1024 - DISK_OVERHEAD_MIB))"

	mkfs.fat -F32 "$ESP_PART" >/dev/null || die "could not format the EFI partition"
	mkfs.btrfs -f -L AstraOS "$ROOT_PART" >/dev/null || die "could not format the root partition"
	verify_filesystem "$ESP_PART" vfat
	verify_filesystem "$ROOT_PART" btrfs

	STATE[root_part]="$ROOT_PART"
	STATE[esp_part]="$ESP_PART"
	STATE[root_fs]="btrfs"
	log "whole-disk layout ready: esp=${ESP_PART} root=${ROOT_PART}"
}

prepare_free_space() {
	local disk=${STATE[disk]}
	local start=${STATE[free_start]} end=${STATE[free_end]}
	local s e x still=0
	local esp_num root_num esp_end root_start

	while IFS=$'\t' read -r s e x; do
		if ((s <= start && e >= end)); then
			still=1
			break
		fi
	done < <(list_free_regions "$disk")
	((still == 1)) ||
		die "the selected free space on ${disk} is no longer free. Run the installer again."

	local baseline=${GPT_BASELINE_FILE}
	if [[ -z ${baseline:-} || ! -r $baseline ]]; then
		baseline="${STATE_DIR}/gpt-baseline-$(basename "$disk").txt"
		snapshot_gpt "$disk" >"$baseline" ||
			die "could not snapshot the partition table of ${disk}"
	fi

	log "creating partitions inside free space ${start}-${end} on ${disk}"
	if [[ ${STATE[esp_mode]} == new ]]; then
		esp_num="$(next_partition_number "$disk")"
		sgdisk -n "${esp_num}:${start}:+1G" -t "${esp_num}:EF00" \
			-c "${esp_num}:AstraOS ESP" "$disk" >/dev/null ||
			die "could not create the EFI partition inside the free space"
		esp_end="$(sgdisk -i "$esp_num" "$disk" 2>/dev/null |
			awk '/^Last sector:/{print $3; exit}')"
		[[ $esp_end =~ ^[0-9]+$ ]] || die "could not read the new EFI partition size"
		root_start=$((esp_end + 1))
		((root_start <= end)) ||
			die "not enough free space for a root partition after the EFI partition"
		root_num=$((esp_num + 1))
		sgdisk -n "${root_num}:${root_start}:${end}" -t "${root_num}:8300" \
			-c "${root_num}:AstraOS root" "$disk" >/dev/null ||
			die "could not create the root partition inside the free space"
		ESP_PART="$(part_path "$disk" "$esp_num")"
		ROOT_PART="$(part_path "$disk" "$root_num")"
	else
		root_num="$(next_partition_number "$disk")"
		sgdisk -n "${root_num}:${start}:${end}" -t "${root_num}:8300" \
			-c "${root_num}:AstraOS root" "$disk" >/dev/null ||
			die "could not create the root partition inside the free space"
		ROOT_PART="$(part_path "$disk" "$root_num")"
		ESP_PART=${STATE[esp_part]}
	fi

	partprobe "$disk" 2>/dev/null || true
	udevadm settle 2>/dev/null || true
	wait_for_partition "$disk" "$ROOT_PART" ||
		die "the new root partition did not appear on ${disk}"
	wait_for_partition "$disk" "$ESP_PART" ||
		die "the EFI partition is not a block device: ${ESP_PART}"

	# Geometry and type checks happen before formatting.  The post-cfdisk
	# baseline then proves that none of the user's existing entries changed.
	if [[ ${STATE[esp_mode]} == new ]]; then
		verify_new_partition "$disk" "$esp_num" "$start" "$end" "$GPT_ESP_GUID" 1024
	fi
	verify_new_partition "$disk" "$root_num" "$start" "$end" "$GPT_LINUX_GUID" \
		"$((MIN_ROOT_GIB * 1024 - DISK_OVERHEAD_MIB))"
	verify_gpt_unchanged "$disk" "$baseline"

	mkfs.btrfs -f -L AstraOS "$ROOT_PART" >/dev/null ||
		die "could not format the new root partition"
	verify_filesystem "$ROOT_PART" btrfs
	if [[ ${STATE[esp_mode]} == new ]]; then
		mkfs.fat -F32 "$ESP_PART" >/dev/null ||
			die "could not format the new EFI partition"
		verify_filesystem "$ESP_PART" vfat
	else
		verify_filesystem "$ESP_PART" vfat
	fi

	STATE[root_part]="$ROOT_PART"
	STATE[esp_part]="$ESP_PART"
	STATE[root_fs]="btrfs"
	log "free-space layout ready: esp=${ESP_PART} root=${ROOT_PART}"
}

prepare_manual() {
	local root=${STATE[root_part]} esp=${STATE[esp_part]}
	[[ -b $root ]] || die "root partition is not a block device: ${root}"
	[[ -b $esp ]] || die "EFI partition is not a block device: ${esp}"
	[[ $root != "$esp" ]] || die "root and EFI partitions cannot be the same partition"

	if [[ -n $(findmnt -S "$root" -n -o TARGET 2>/dev/null | head -n1) ]]; then
		die "${root} is mounted. Unmount it before installing."
	fi

	log "formatting manual root partition ${root}"
	mkfs.btrfs -f -L AstraOS "$root" >/dev/null ||
		die "could not format ${root}"
	verify_filesystem "$root" btrfs
	verify_filesystem "$esp" vfat
	ROOT_PART="$root"
	ESP_PART="$esp"
	STATE[root_fs]="btrfs"
	log "manual layout ready: esp=${ESP_PART} root=${ROOT_PART} (ESP not formatted)"
}

prepare_premounted() {
	MNT_ROOT=${STATE[premounted_root]:-/mnt}
	ESP_MOUNT=${STATE[esp_mount]:-/boot/efi}
	ROOT_PART=${STATE[root_part]}
	ESP_PART=${STATE[esp_part]}
	mountpoint -q "$MNT_ROOT" ||
		die "pre-mounted root ${MNT_ROOT} is no longer mounted"
	mountpoint -q "${MNT_ROOT}${ESP_MOUNT}" ||
		die "pre-mounted EFI ${MNT_ROOT}${ESP_MOUNT} is no longer mounted"
	verify_filesystem "$ESP_PART" vfat
	KEEP_MOUNTS=1
	MOUNTS_CREATED=0
	verify_install_target
	log "using pre-mounted root ${MNT_ROOT}, ESP ${MNT_ROOT}${ESP_MOUNT}"
}

# Guard against a catastrophic mis-target before any package is written.  The
# 40 GiB test disk exposed an old failure where pacstrap used the 256 MiB live
# overlay as its cache; this check also proves that /mnt is really backed by the
# selected root partition rather than the live installer filesystem.
verify_install_target() {
	local source root_part avail_kib min_kib=$((10 * 1024 * 1024))
	source="$(findmnt -n -o SOURCE -T "$MNT_ROOT" 2>/dev/null | head -n1 || true)"
	# Btrfs subvolumes are reported as /dev/sda2[/@].  Compare the backing
	# device, not the subvolume suffix, and normalize premounted sources too.
	source="${source%%\[*}"
	root_part="${ROOT_PART%%\[*}"
	[[ -n ${source:-} ]] ||
		die "could not determine the filesystem mounted at ${MNT_ROOT}"
	[[ $source == "$root_part" ]] ||
		die "target root ${MNT_ROOT} is backed by ${source}, not ${root_part}. Refusing to install."

	avail_kib="$(df -Pk "$MNT_ROOT" 2>/dev/null | awk 'NR == 2 {print $4}')"
	[[ $avail_kib =~ ^[0-9]+$ ]] ||
		die "could not read free space on ${MNT_ROOT}"
	((avail_kib >= min_kib)) ||
		die "target root ${MNT_ROOT} has only $((avail_kib / 1024)) MiB free; at least 10 GiB is required"

	log "verified target ${MNT_ROOT}: source=${source}, free=$((avail_kib / 1024)) MiB"
}

mount_target() {
	if [[ ${STATE[storage_mode]} == premounted ]]; then
		return 0
	fi

	MNT_ROOT="/mnt"
	ESP_MOUNT=${STATE[esp_mount]:-/boot/efi}
	mkdir -p "$MNT_ROOT" || die "cannot create ${MNT_ROOT}"
	if mountpoint -q "$MNT_ROOT"; then
		die "${MNT_ROOT} is already mounted. Unmount it first."
	fi

	mount "$ROOT_PART" "$MNT_ROOT" ||
		die "could not mount root partition ${ROOT_PART}"
	# Mark the target as ours immediately.  If a later step (subvolume create,
	# ESP mount, installation) fails, die()/on_exit() can unmount the half-set-up
	# target instead of leaving mounts behind.
	MOUNTS_CREATED=1

	local opts="noatime,compress=zstd:1,discard=async"
	local sub
	for sub in @ @home @log @pkg @snapshots; do
		btrfs subvolume create "$MNT_ROOT/$sub" >/dev/null 2>&1 ||
			die "could not create Btrfs subvolume ${sub}"
	done
	umount "$MNT_ROOT" || die "could not remount the Btrfs root"

	mount -o "subvol=@,$opts" "$ROOT_PART" "$MNT_ROOT" ||
		die "could not mount Btrfs subvolume @"
	mkdir -p "$MNT_ROOT"/{home,var/log,var/cache/pacman/pkg,.snapshots,boot}
	mount -o "subvol=@home,$opts" "$ROOT_PART" "$MNT_ROOT/home" ||
		die "could not mount Btrfs subvolume @home"
	mount -o "subvol=@log,$opts" "$ROOT_PART" "$MNT_ROOT/var/log" ||
		die "could not mount Btrfs subvolume @log"
	mount -o "subvol=@pkg,$opts" "$ROOT_PART" "$MNT_ROOT/var/cache/pacman/pkg" ||
		die "could not mount Btrfs subvolume @pkg"
	mount -o "subvol=@snapshots,$opts" "$ROOT_PART" "$MNT_ROOT/.snapshots" ||
		die "could not mount Btrfs subvolume @snapshots"

	mkdir -p "${MNT_ROOT}${ESP_MOUNT}" ||
		die "cannot create EFI mountpoint ${MNT_ROOT}${ESP_MOUNT}"
	if ! mountpoint -q "${MNT_ROOT}${ESP_MOUNT}"; then
		mount "$ESP_PART" "${MNT_ROOT}${ESP_MOUNT}" ||
			die "could not mount EFI partition ${ESP_PART}"
	fi

	verify_install_target
	log "mounted target at ${MNT_ROOT}"
}

cleanup_mounts() {
	if ((MOUNTS_CREATED == 1 && KEEP_MOUNTS == 0)); then
		if mountpoint -q "$MNT_ROOT"; then
			umount -R "$MNT_ROOT" 2>/dev/null ||
				umount -lR "$MNT_ROOT" 2>/dev/null || true
			log "unmounted ${MNT_ROOT}"
		fi
	fi
	MOUNTS_CREATED=0
}
