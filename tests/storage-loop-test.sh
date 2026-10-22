#!/usr/bin/env bash
# Destructive-storage tests that only ever touch loopback image files.
#
# Requirements:
#   * run as root (loop devices, mkfs, mount)
#   * no host block device is ever passed to the installer code
#
# The test exercises prepare_free_space() and prepare_whole_disk() from the
# real installer library, not a mock.  It verifies GPT metadata, first-MiB
# hashes, filesystem types, and the free-space promise.
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
lib="${root}/packages/astra-installer/lib"

if ((EUID != 0)); then
	printf 'storage-loop-test: must run as root\n' >&2
	exit 77
fi

work=/var/tmp/astra-storage-test
state="${work}/state"
img="${work}/free.img"
existing_img="${work}/existing.img"
manual_img="${work}/manual.img"
whole_img="${work}/whole.img"
mnt="${work}/mnt"
loop=""
mounted=0

cleanup() {
	set +e
	if ((mounted == 1)); then
		umount "$mnt" 2>/dev/null || umount -l "$mnt" 2>/dev/null
		mounted=0
	fi
	if [[ -n ${loop:-} ]]; then
		losetup -d "$loop" 2>/dev/null
	fi
	rm -rf -- "$work"
}
trap cleanup EXIT

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

assert_eq() {
	[[ $1 == "$2" ]] || fail "expected '$2', got '$1' ($3)"
}

assert_ge() {
	[[ $1 =~ ^[0-9]+$ ]] || fail "not a number: '$1' ($3)"
	(($1 >= $2)) || fail "expected >= $2, got $1 ($3)"
}

rm -rf -- "$work"
mkdir -p "$state" "$mnt"
export STATE_DIR="$state"
export LOG="${state}/install.log"

# shellcheck source=../packages/astra-installer/lib/common.sh
source "${lib}/common.sh"
# shellcheck source=../packages/astra-installer/lib/storage.sh
source "${lib}/storage.sh"

part_num_path() {
	part_path "$loop" "$1"
}

make_free_image() {
	local p1
	truncate -s 40G "$img"
	sgdisk --zap-all "$img" >/dev/null
	sgdisk -n 1:2048:+524288 -t 1:8300 -c 1:KEEP-ME "$img" >/dev/null
	loop=$(losetup --find --show --partscan "$img")
	[[ $loop == /dev/loop* ]] || fail "refusing to test non-loop device: $loop"
	p1=$(part_num_path 1)
	for _ in {1..50}; do
		[[ -b $p1 ]] && break
		sleep 0.1
	done
	[[ -b $p1 ]] || fail "existing test partition did not appear: $p1"
	mkfs.ext4 -q -F -L KEEPME "$p1"
	mount "$p1" "$mnt"
	mounted=1
	printf 'keep this data\n' >"${mnt}/marker"
	sync
	umount "$mnt"
	mounted=0
}

test_free_space() {
	local old_line new_line start end mib root_bytes esp_bytes rc=0
	make_free_image

	old_line="$(snapshot_gpt "$loop" | awk -F'|' '$1 == 1')"
	[[ -n $old_line ]] || fail "could not snapshot the existing partition"
	GPT_BASELINE_FILE="${state}/baseline"
	snapshot_gpt "$loop" >"$GPT_BASELINE_FILE"

	read -r start end mib < <(
		list_free_regions "$loop" | sort -t$'\t' -k3,3n | tail -n1
	)
	[[ -n ${start:-} && -n ${end:-} && -n ${mib:-} ]] ||
		fail "no free region found on the test image"
	assert_ge "$mib" 35840 "free region must fit 34 GiB root + 1 GiB ESP"

	STATE[disk]="$loop"
	STATE[disk_size]="40G"
	STATE[esp_mode]="new"
	STATE[format_root]="yes"
	STATE[free_start]="$start"
	STATE[free_end]="$end"
	STATE[free_mib]="$mib"
	STATE[free_size]="${mib} MiB"

	prepare_free_space || rc=$?
	((rc == 0)) || fail "prepare_free_space returned ${rc}"

	[[ ${STATE[esp_mode]} == new ]] || fail "ESP mode changed unexpectedly"
	[[ -b ${ESP_PART:-} ]] || fail "ESP_PART is not a block device"
	[[ -b ${ROOT_PART:-} ]] || fail "ROOT_PART is not a block device"
	verify_filesystem "$ESP_PART" vfat
	verify_filesystem "$ROOT_PART" btrfs
	assert_eq "${STATE[esp_part]}" "$ESP_PART" "ESP state"
	assert_eq "${STATE[root_part]}" "$ROOT_PART" "root state"

	new_line="$(snapshot_gpt "$loop" | awk -F'|' '$1 == 1')"
	assert_eq "$new_line" "$old_line" "existing partition metadata and first-MiB hash"

	mount "$(part_num_path 1)" "$mnt"
	mounted=1
	[[ $(cat "${mnt}/marker") == "keep this data" ]] ||
		fail "existing data was not preserved"
	umount "$mnt"
	mounted=0

	root_bytes=$(blockdev --getsize64 "$ROOT_PART")
	esp_bytes=$(blockdev --getsize64 "$ESP_PART")
	assert_ge "$root_bytes" $((34 * 1024 * 1024 * 1024)) "root size"
	assert_ge "$esp_bytes" $((1 * 1024 * 1024 * 1024)) "ESP size"

	# The installer-created partitions must consume the selected region and no
	# existing partition may have moved.
	if list_free_regions "$loop" |
		awk -v s="$start" -v e="$end" '$1 <= s && $2 >= e { found = 1 } END { exit found ? 0 : 1 }'; then
		fail "the selected free region is still reported as free"
	fi

	# Only one existing partition should remain at number 1; new entries are 2/3.
	assert_eq "$(sgdisk -p "$loop" | awk '/^Number/{f=1;next} f && $1 ~ /^[0-9]+$/ {n++} END{print n+0}')" \
		"3" "partition count after free-space install"

	printf 'free-space: ok (existing data kept, root=%s, esp=%s)\n' \
		"$ROOT_PART" "$ESP_PART"
	losetup -d "$loop"
	loop=""
}

test_free_space_existing_esp() {
	local p1 p2 esp_line data_line root_bytes start end mib rc=0
	truncate -s 40G "$existing_img"
	sgdisk --zap-all "$existing_img" >/dev/null
	sgdisk -n 1:2048:+2097152 -t 1:EF00 -c 1:EXISTING-ESP "$existing_img" >/dev/null
	sgdisk -n 2:0:+1048576 -t 2:8300 -c 2:KEEP-DATA "$existing_img" >/dev/null
	loop=$(losetup --find --show --partscan "$existing_img")
	[[ $loop == /dev/loop* ]] || fail "refusing to test non-loop device: $loop"
	p1=$(part_num_path 1)
	p2=$(part_num_path 2)
	for _ in {1..50}; do
		[[ -b $p1 && -b $p2 ]] && break
		sleep 0.1
	done
	[[ -b $p1 && -b $p2 ]] || fail "existing ESP/data partitions did not appear"
	mkfs.fat -F32 "$p1" >/dev/null
	mkfs.ext4 -q -F -L KEEPDATA "$p2"
	mount "$p2" "$mnt"
	mounted=1
	printf 'keep existing data\n' >"${mnt}/marker"
	sync
	umount "$mnt"
	mounted=0

	esp_line="$(snapshot_gpt "$loop" | awk -F'|' '$1 == 1')"
	data_line="$(snapshot_gpt "$loop" | awk -F'|' '$1 == 2')"
	[[ -n $esp_line && -n $data_line ]] || fail "could not snapshot existing ESP/data"
	GPT_BASELINE_FILE="${state}/baseline-existing"
	snapshot_gpt "$loop" >"$GPT_BASELINE_FILE"

	read -r start end mib < <(
		list_free_regions "$loop" | sort -t$'\t' -k3,3n | tail -n1
	)
	[[ -n ${start:-} && -n ${end:-} && -n ${mib:-} ]] ||
		fail "no free region found on the existing-ESP image"
	assert_ge "$mib" 34816 "free region must fit a 34 GiB root"

	STATE[disk]="$loop"
	STATE[disk_size]="40G"
	STATE[esp_mode]="existing"
	STATE[esp_part]="$p1"
	STATE[format_root]="yes"
	STATE[free_start]="$start"
	STATE[free_end]="$end"
	STATE[free_mib]="$mib"
	STATE[free_size]="${mib} MiB"

	prepare_free_space || rc=$?
	((rc == 0)) || fail "prepare_free_space (existing ESP) returned ${rc}"

	assert_eq "${STATE[esp_part]}" "$p1" "existing ESP state"
	[[ ${ROOT_PART:-} != "$p1" && ${ROOT_PART:-} != "$p2" ]] ||
		fail "new root reused an existing partition"
	verify_filesystem "$p1" vfat
	verify_filesystem "$ROOT_PART" btrfs

	assert_eq "$(snapshot_gpt "$loop" | awk -F'|' '$1 == 1')" "$esp_line" \
		"existing ESP metadata and first-MiB hash"
	assert_eq "$(snapshot_gpt "$loop" | awk -F'|' '$1 == 2')" "$data_line" \
		"existing data partition metadata and first-MiB hash"

	mount "$p2" "$mnt"
	mounted=1
	[[ $(cat "${mnt}/marker") == "keep existing data" ]] ||
		fail "existing ESP-mode data was not preserved"
	umount "$mnt"
	mounted=0

	root_bytes=$(blockdev --getsize64 "$ROOT_PART")
	assert_ge "$root_bytes" $((34 * 1024 * 1024 * 1024)) "existing-ESP root size"
	assert_eq "$(sgdisk -p "$loop" | awk '/^Number/{f=1;next} f && $1 ~ /^[0-9]+$/ {n++} END{print n+0}')" \
		"3" "existing-ESP partition count"

	printf 'free-space-existing-esp: ok (existing ESP kept, root=%s)\n' "$ROOT_PART"
	losetup -d "$loop"
	loop=""
}

test_manual() {
	local p1 p2 esp_line start
	truncate -s 40G "$manual_img"
	sgdisk --zap-all "$manual_img" >/dev/null
	sgdisk -n 1:2048:+2097152 -t 1:EF00 -c 1:EXISTING-ESP "$manual_img" >/dev/null
	sgdisk -n 2:0:0 -t 2:8300 -c 2:MANUAL-ROOT "$manual_img" >/dev/null
	loop=$(losetup --find --show --partscan "$manual_img")
	[[ $loop == /dev/loop* ]] || fail "refusing to test non-loop device: $loop"
	p1=$(part_num_path 1)
	p2=$(part_num_path 2)
	for _ in {1..50}; do
		[[ -b $p1 && -b $p2 ]] && break
		sleep 0.1
	done
	[[ -b $p1 && -b $p2 ]] || fail "manual test partitions did not appear"
	mkfs.fat -F32 "$p1" >/dev/null
	mkfs.ext4 -q -F -L MANUALROOT "$p2"
	mount "$p2" "$mnt"
	mounted=1
	printf 'old root data\n' >"${mnt}/old-root-marker"
	sync
	umount "$mnt"
	mounted=0

	esp_line="$(snapshot_gpt "$loop" | awk -F'|' '$1 == 1')"
	[[ -n $esp_line ]] || fail "could not snapshot the manual-test ESP"
	start="$(sgdisk -p "$loop" | awk '/^Number/{f=1;next} f && $1 == 2 {print $2}')"
	[[ -n $start ]] || fail "could not read manual-test root geometry"

	STATE[disk]="$loop"
	STATE[disk_size]="40G"
	STATE[storage_mode]="manual"
	STATE[esp_mode]="existing"
	STATE[esp_part]="$p1"
	STATE[root_part]="$p2"
	STATE[format_root]="yes"
	STATE[format_esp]="no"

	prepare_manual
	verify_filesystem "$p1" vfat
	verify_filesystem "$p2" btrfs
	assert_eq "$(snapshot_gpt "$loop" | awk -F'|' '$1 == 1')" "$esp_line" \
		"manual mode must not touch the existing ESP"

	printf 'manual: ok (ESP kept, root reformatted as btrfs)\n'
	losetup -d "$loop"
	loop=""
}

test_whole_disk_too_small() {
	local small_img="${work}/small.img" small_loop before after
	truncate -s 2G "$small_img"
	sgdisk --zap-all "$small_img" >/dev/null
	sgdisk -n 1:2048:+262144 -t 1:8300 -c 1:DO-NOT-TOUCH "$small_img" >/dev/null
	small_loop=$(losetup --find --show --partscan "$small_img")
	[[ $small_loop == /dev/loop* ]] || fail "refusing to test non-loop device: $small_loop"
	for _ in {1..50}; do
		[[ -b ${small_loop}p1 ]] && break
		sleep 0.1
	done
	before="$(sgdisk -p "$small_loop")"

	if (
		# shellcheck disable=SC2329
		choose_disk() {
			STATE[disk]="$small_loop"
			STATE[disk_size]="2G"
		}
		# shellcheck disable=SC2329
		show_disks() { :; }
		# shellcheck disable=SC2329
		ui_markdown() { :; }
		whole_disk_setup
	); then
		losetup -d "$small_loop"
		fail "whole_disk_setup accepted a disk smaller than root + ESP"
	fi

	after="$(sgdisk -p "$small_loop")"
	[[ $after == "$before" ]] ||
		fail "whole_disk_setup changed the GPT before the size check passed"
	losetup -d "$small_loop"
	printf 'whole-disk-too-small: ok (refused without touching the GPT)\n'
}

test_whole_disk() {
	local root_bytes
	truncate -s 40G "$whole_img"
	loop=$(losetup --find --show --partscan "$whole_img")
	[[ $loop == /dev/loop* ]] || fail "refusing to test non-loop device: $loop"

	STATE[disk]="$loop"
	STATE[disk_size]="40G"
	STATE[storage_mode]="whole"
	STATE[esp_mode]="new"
	STATE[format_root]="yes"
	STATE[format_esp]="yes"

	prepare_whole_disk
	[[ -b ${ESP_PART:-} ]] || fail "whole-disk ESP_PART is not a block device"
	[[ -b ${ROOT_PART:-} ]] || fail "whole-disk ROOT_PART is not a block device"
	verify_filesystem "$ESP_PART" vfat
	verify_filesystem "$ROOT_PART" btrfs

	root_bytes=$(blockdev --getsize64 "$ROOT_PART")
	assert_ge "$root_bytes" $((34 * 1024 * 1024 * 1024)) "whole-disk root size"
	assert_eq "$(sgdisk -p "$loop" | awk '/^Number/{f=1;next} f && $1 ~ /^[0-9]+$/ {n++} END{print n+0}')" \
		"2" "whole-disk partition count"

	printf 'whole-disk: ok (root=%s, esp=%s)\n' "$ROOT_PART" "$ESP_PART"
	losetup -d "$loop"
	loop=""
}

printf 'storage-loop-test: starting (image files only)\n'
test_free_space
test_free_space_existing_esp
test_manual
test_whole_disk_too_small
test_whole_disk
printf 'storage-loop-test: ok\n'
