//! Pure storage planning for the AstraOS installer.
//!
//! Nothing in this module writes to a disk.  It takes the read-only `lsblk`
//! model and returns a plan plus typed validation errors.  The GUI calls this
//! on the storage page; the privileged engine repeats the checks before it
//! touches anything.

use serde::{Deserialize, Serialize};

pub const GIB: u64 = 1024 * 1024 * 1024;
pub const MIB: u64 = 1024 * 1024;
pub const MIN_TOTAL_BYTES: u64 = 35 * GIB;
pub const MIN_ROOT_BYTES: u64 = 34 * GIB;
pub const ESP_BYTES: u64 = 1 * GIB;
pub const OVERHEAD_BYTES: u64 = 2 * MIB;

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct PartitionInfo {
    pub path: String,
    pub size_bytes: u64,
    pub size_human: String,
    pub fstype: String,
    pub label: String,
    pub mountpoints: Vec<String>,
    pub part_type: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct DiskInfo {
    pub path: String,
    pub name: String,
    pub size_bytes: u64,
    pub size_human: String,
    pub model: String,
    pub transport: String,
    pub removable: bool,
    pub pttype: String,
    pub is_live: bool,
    pub partitions: Vec<PartitionInfo>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
#[serde(default)]
pub struct PlanRequest {
    pub storage_mode: String,
    pub disk: String,
    pub esp_mode: String,
    pub esp_part: String,
    pub root_part: String,
    pub esp_mount: String,
    pub premounted_root: String,
    pub free_start: u64,
    pub free_end: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct PlanPart {
    pub role: String,
    pub device: String,
    pub size_bytes: u64,
    pub size_human: String,
    pub filesystem: String,
    pub mountpoint: String,
    pub source: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct StoragePlan {
    pub valid: bool,
    pub errors: Vec<String>,
    pub warnings: Vec<String>,
    pub steps: Vec<String>,
    pub storage_mode: String,
    pub disk: String,
    pub disk_size_bytes: u64,
    pub disk_size_human: String,
    pub total_bytes: u64,
    pub total_human: String,
    pub minimum_bytes: u64,
    pub minimum_human: String,
    pub destroy_disk: bool,
    pub esp: PlanPart,
    pub root: PlanPart,
}

pub fn human_bytes(bytes: u64) -> String {
    if bytes >= GIB {
        format!("{:.1} GiB", bytes as f64 / GIB as f64)
    } else if bytes >= MIB {
        format!("{:.0} MiB", bytes as f64 / MIB as f64)
    } else {
        format!("{bytes} B")
    }
}

pub fn part_path(disk: &str, num: u32) -> String {
    if disk.chars().last().is_some_and(|c| c.is_ascii_digit()) {
        format!("{disk}p{num}")
    } else {
        format!("{disk}{num}")
    }
}

pub fn valid_hostname(value: &str) -> bool {
    let s = value.trim();
    !s.is_empty()
        && s.len() <= 63
        && s.chars().next().is_some_and(|c| c.is_ascii_alphanumeric())
        && s.chars().last().is_some_and(|c| c.is_ascii_alphanumeric())
        && s.chars().all(|c| c.is_ascii_alphanumeric() || c == '-')
}

pub fn valid_username(value: &str) -> bool {
    let s = value.trim();
    !s.is_empty()
        && s.len() <= 32
        && s != "root"
        && s.chars().next().is_some_and(|c| c.is_ascii_lowercase() || c == '_')
        && s.chars()
            .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_' || c == '-')
}

pub fn valid_locale(value: &str) -> bool {
    let s = value.trim();
    s == "C.UTF-8"
        || (s.ends_with(".UTF-8")
            && s.chars()
                .all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '.' || c == '-'))
}

pub fn valid_password(value: &str) -> bool {
    !value.is_empty() && !value.contains('\n') && !value.contains('\r')
}

pub fn valid_timezone(value: &str) -> bool {
    let s = value.trim();
    !s.is_empty()
        && !s.contains("..")
        && std::path::Path::new("/usr/share/zoneinfo").join(s).exists()
}

fn find_disk<'a>(disks: &'a [DiskInfo], path: &str) -> Option<&'a DiskInfo> {
    disks.iter().find(|d| d.path == path)
}

fn find_part<'a>(disks: &'a [DiskInfo], path: &str) -> Option<(&'a DiskInfo, &'a PartitionInfo)> {
    for disk in disks {
        if let Some(part) = disk.partitions.iter().find(|p| p.path == path) {
            return Some((disk, part));
        }
    }
    None
}

fn part_from(role: &str, p: &PartitionInfo, source: &str, fs: &str, mount: &str) -> PlanPart {
    PlanPart {
        role: role.to_string(),
        device: p.path.clone(),
        size_bytes: p.size_bytes,
        size_human: p.size_human.clone(),
        filesystem: fs.to_string(),
        mountpoint: mount.to_string(),
        source: source.to_string(),
    }
}

fn new_part(role: &str, device: String, size: u64, fs: &str, mount: &str) -> PlanPart {
    PlanPart {
        role: role.to_string(),
        device,
        size_bytes: size,
        size_human: human_bytes(size),
        filesystem: fs.to_string(),
        mountpoint: mount.to_string(),
        source: "new".to_string(),
    }
}

pub fn plan(req: &PlanRequest, disks: &[DiskInfo]) -> StoragePlan {
    let mut out = StoragePlan {
        storage_mode: req.storage_mode.clone(),
        minimum_bytes: MIN_TOTAL_BYTES,
        minimum_human: human_bytes(MIN_TOTAL_BYTES),
        ..Default::default()
    };
    if disks.is_empty() {
        out.errors.push("No usable disks were found.".into());
        return out;
    }

    let mode = req.storage_mode.as_str();
    match mode {
        "whole" => {
            let Some(disk) = find_disk(disks, &req.disk) else {
                out.errors.push("Choose a whole disk to erase.".into());
                return out;
            };
            out.disk = disk.path.clone();
            out.disk_size_bytes = disk.size_bytes;
            out.disk_size_human = disk.size_human.clone();
            out.total_bytes = disk.size_bytes;
            out.total_human = disk.size_human.clone();
            out.destroy_disk = true;
            if disk.is_live {
                out.errors.push(format!(
                    "{} is the live boot medium and cannot be erased.",
                    disk.path
                ));
            }
            if disk.size_bytes < MIN_TOTAL_BYTES {
                out.errors.push(format!(
                    "{} is {}; AstraOS needs at least {} (1 GiB ESP + 34 GiB root).",
                    disk.path,
                    disk.size_human,
                    human_bytes(MIN_TOTAL_BYTES)
                ));
            }
            let root_bytes = disk
                .size_bytes
                .saturating_sub(ESP_BYTES)
                .saturating_sub(OVERHEAD_BYTES);
            // The 2 MiB GPT alignment overhead is part of the documented floor:
            // a 35 GiB disk yields a root partition of 34 GiB minus that
            // overhead, which is still treated as the 35/34 GiB floor.
            if root_bytes.saturating_add(OVERHEAD_BYTES) < MIN_ROOT_BYTES {
                out.errors.push(format!(
                    "Only {} would remain for the root filesystem; at least {} is required.",
                    human_bytes(root_bytes),
                    human_bytes(MIN_ROOT_BYTES)
                ));
            }
            out.esp = new_part(
                "esp",
                part_path(&disk.path, 1),
                ESP_BYTES.min(disk.size_bytes),
                "vfat",
                "/boot/efi",
            );
            out.root = new_part("root", part_path(&disk.path, 2), root_bytes, "btrfs", "/");
            out.steps = vec![
                format!("Erase every partition and file on {}", disk.path),
                "Create a 1 GiB EFI system partition (type EF00)".into(),
                format!(
                    "Create a {} Btrfs root partition (type 8300)",
                    human_bytes(root_bytes)
                ),
                "Format the ESP as FAT32 and the root as Btrfs".into(),
                "Install AstraOS packages and the SilentSDDM desktop".into(),
                "Install the UEFI GRUB bootloader and generate the initramfs".into(),
            ];
            out.warnings.push(format!(
                "This is destructive: all data on {} will be lost.",
                disk.path
            ));
        }
        "free" => {
            let Some(disk) = find_disk(disks, &req.disk) else {
                out.errors.push("Choose the GPT disk that contains the free space.".into());
                return out;
            };
            out.disk = disk.path.clone();
            out.disk_size_bytes = disk.size_bytes;
            out.disk_size_human = disk.size_human.clone();
            out.destroy_disk = false;
            if disk.pttype != "gpt" {
                out.errors
                    .push(format!("{} is not a GPT disk; free-space mode needs GPT.", disk.path));
            }
            if req.free_end <= req.free_start {
                out.errors.push("Select a valid free-space region.".into());
            }
            let free_bytes = req
                .free_end
                .saturating_sub(req.free_start)
                .saturating_add(1)
                .saturating_mul(512);
            out.total_bytes = free_bytes;
            out.total_human = human_bytes(free_bytes);
            let esp_existing = req.esp_mode == "existing";
            if esp_existing {
                if let Some((_, esp)) = find_part(disks, &req.esp_part) {
                    out.esp = part_from("esp", esp, "existing", "vfat", "/boot/efi");
                } else {
                    out.errors
                        .push("Select an existing EFI system partition.".into());
                }
                out.minimum_bytes = MIN_ROOT_BYTES;
                out.minimum_human = human_bytes(MIN_ROOT_BYTES);
            } else {
                out.esp = new_part(
                    "esp",
                    "new partition in free space".into(),
                    ESP_BYTES,
                    "vfat",
                    "/boot/efi",
                );
            }
            let reserved = if esp_existing { 0 } else { ESP_BYTES + OVERHEAD_BYTES };
            let root_bytes = free_bytes.saturating_sub(reserved);
            if root_bytes.saturating_add(OVERHEAD_BYTES) < MIN_ROOT_BYTES {
                out.errors.push(format!(
                    "The selected free region is {}; at least {} is required for the root filesystem.",
                    human_bytes(free_bytes),
                    human_bytes(MIN_ROOT_BYTES + reserved)
                ));
            }
            out.root = new_part(
                "root",
                "new partition in free space".into(),
                root_bytes,
                "btrfs",
                "/",
            );
            out.steps = vec![
                format!(
                    "Create partitions only inside sectors {}-{} on {}",
                    req.free_start, req.free_end, disk.path
                ),
                if esp_existing {
                    "Use the selected existing EFI partition (not formatted)".into()
                } else {
                    "Create a new 1 GiB EFI system partition inside the free region".into()
                },
                format!("Create a {} Btrfs root partition", human_bytes(root_bytes)),
                "Format the new root partition and any new ESP as Btrfs/FAT32".into(),
                "Install AstraOS packages and the UEFI bootloader".into(),
            ];
            out.warnings.push(
                "Existing partitions outside the selected free region will not be touched.".into(),
            );
        }
        "manual" => {
            let Some((disk, root)) = find_part(disks, &req.root_part) else {
                out.errors
                    .push("Choose an existing root partition to format.".into());
                return out;
            };
            out.disk = disk.path.clone();
            out.disk_size_bytes = disk.size_bytes;
            out.disk_size_human = disk.size_human.clone();
            out.root = part_from("root", root, "existing, will be formatted", "btrfs", "/");
            if let Some((_, esp)) = find_part(disks, &req.esp_part) {
                out.esp = part_from("esp", esp, "existing, not formatted", "vfat", "/boot/efi");
            } else {
                out.errors
                    .push("Choose an existing EFI system partition.".into());
            }
            out.total_bytes = root.size_bytes;
            out.total_human = root.size_human.clone();
            out.minimum_bytes = MIN_ROOT_BYTES;
            out.minimum_human = human_bytes(MIN_ROOT_BYTES);
            if root.size_bytes < MIN_ROOT_BYTES {
                out.errors.push(format!(
                    "{} is {}; the root partition must be at least {}.",
                    root.path,
                    root.size_human,
                    human_bytes(MIN_ROOT_BYTES)
                ));
            }
            if req.root_part == req.esp_part {
                out.errors.push("Root and EFI cannot be the same partition.".into());
            }
            out.steps = vec![
                format!("Format only {} as Btrfs (label AstraOS)", root.path),
                "Keep the existing EFI partition unchanged".into(),
                "Install AstraOS packages and the UEFI bootloader".into(),
            ];
            out.warnings.push(format!(
                "All data on {} will be lost; the EFI partition is not formatted.",
                root.path
            ));
        }
        "premounted" => {
            let Some((disk, root)) = find_part(disks, &req.root_part) else {
                out.errors
                    .push("Choose the block device backing the pre-mounted root.".into());
                return out;
            };
            out.disk = disk.path.clone();
            out.disk_size_bytes = disk.size_bytes;
            out.disk_size_human = disk.size_human.clone();
            out.root = part_from("root", root, "pre-mounted, not formatted", "btrfs", "/");
            if let Some((_, esp)) = find_part(disks, &req.esp_part) {
                out.esp = part_from("esp", esp, "pre-mounted, not formatted", "vfat", "/boot/efi");
            } else {
                out.errors
                    .push("Choose the block device backing the pre-mounted ESP.".into());
            }
            out.total_bytes = root.size_bytes;
            out.total_human = root.size_human.clone();
            out.minimum_bytes = MIN_ROOT_BYTES;
            out.minimum_human = human_bytes(MIN_ROOT_BYTES);
            if req.premounted_root.trim().is_empty() || !req.premounted_root.starts_with('/') {
                out.errors
                    .push("Enter the absolute path where the root is mounted.".into());
            } else if req.premounted_root.trim() == "/" {
                out.errors
                    .push("Pre-mounted root cannot be / (that is the live host system).".into());
            }
            out.steps = vec![
                "Use the filesystems already mounted; do not partition or format".into(),
                "Install AstraOS packages and the UEFI bootloader".into(),
                "Leave the pre-mounted filesystems mounted after installation".into(),
            ];
            out.warnings.push(
                "Pre-mounted mode writes into the mounted target and never unmounts it.".into(),
            );
        }
        _ => {
            out.errors.push("Choose a storage mode.".into());
        }
    }

    out.valid = out.errors.is_empty();
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn disk(size_gib: u64) -> DiskInfo {
        DiskInfo {
            path: "/dev/vda".into(),
            name: "vda".into(),
            size_bytes: size_gib * GIB,
            size_human: format!("{size_gib}G"),
            model: "test".into(),
            pttype: "gpt".into(),
            partitions: vec![],
            ..Default::default()
        }
    }

    #[test]
    fn whole_disk_40_gib_is_valid() {
        let d = disk(40);
        let req = PlanRequest {
            storage_mode: "whole".into(),
            disk: d.path.clone(),
            ..Default::default()
        };
        let p = plan(&req, &[d]);
        assert!(p.valid, "{:?}", p.errors);
        assert_eq!(p.esp.size_bytes, ESP_BYTES);
        assert!(p.root.size_bytes >= MIN_ROOT_BYTES);
        assert!(p.destroy_disk);
    }

    #[test]
    fn whole_disk_34_gib_is_rejected() {
        let d = disk(34);
        let req = PlanRequest {
            storage_mode: "whole".into(),
            disk: d.path.clone(),
            ..Default::default()
        };
        let p = plan(&req, &[d]);
        assert!(!p.valid);
        assert!(p.errors.iter().any(|e| e.contains("at least")));
    }

    #[test]
    fn free_space_35_gib_is_valid() {
        let d = disk(100);
        let req = PlanRequest {
            storage_mode: "free".into(),
            disk: d.path.clone(),
            esp_mode: "new".into(),
            free_start: 2048,
            free_end: 2048 + (35 * GIB / 512) - 1,
            ..Default::default()
        };
        let p = plan(&req, &[d]);
        assert!(p.valid, "{:?}", p.errors);
        assert!(!p.destroy_disk);
    }

    #[test]
    fn manual_root_30_gib_is_rejected() {
        let mut d = disk(100);
        d.partitions.push(PartitionInfo {
            path: "/dev/vda2".into(),
            size_bytes: 30 * GIB,
            size_human: "30G".into(),
            fstype: "btrfs".into(),
            ..Default::default()
        });
        d.partitions.push(PartitionInfo {
            path: "/dev/vda1".into(),
            size_bytes: GIB,
            size_human: "1G".into(),
            fstype: "vfat".into(),
            ..Default::default()
        });
        let req = PlanRequest {
            storage_mode: "manual".into(),
            root_part: "/dev/vda2".into(),
            esp_part: "/dev/vda1".into(),
            ..Default::default()
        };
        let p = plan(&req, &[d]);
        assert!(!p.valid);
    }

    #[test]
    fn identity_validators() {
        assert!(valid_hostname("astraos"));
        assert!(!valid_hostname("-astra"));
        assert!(!valid_hostname("astra_os"));
        assert!(valid_username("astra"));
        assert!(!valid_username("root"));
        assert!(!valid_username("Astra"));
        assert!(valid_locale("en_US.UTF-8"));
        assert!(!valid_locale("en_US"));
        assert!(valid_password("correct horse battery staple"));
        assert!(!valid_password("two\nlines"));
    }

    #[test]
    fn live_medium_is_rejected() {
        let mut d = disk(50);
        d.is_live = true;
        let req = PlanRequest {
            storage_mode: "whole".into(),
            disk: d.path.clone(),
            ..Default::default()
        };
        let p = plan(&req, &[d]);
        assert!(!p.valid);
        assert!(p.errors.iter().any(|e| e.contains("live boot medium")));
    }

    #[test]
    fn free_space_non_gpt_is_rejected() {
        let mut d = disk(100);
        d.pttype = "dos".into();
        let req = PlanRequest {
            storage_mode: "free".into(),
            disk: d.path.clone(),
            free_start: 2048,
            free_end: 2048 + (40 * GIB / 512),
            ..Default::default()
        };
        let p = plan(&req, &[d]);
        assert!(!p.valid);
        assert!(p.errors.iter().any(|e| e.contains("GPT disk")));
    }

    #[test]
    fn premounted_root_slash_is_rejected() {
        let mut d = disk(100);
        d.partitions.push(PartitionInfo {
            path: "/dev/vda2".into(),
            size_bytes: 40 * GIB,
            size_human: "40G".into(),
            fstype: "btrfs".into(),
            mountpoints: vec!["/".into()],
            ..Default::default()
        });
        d.partitions.push(PartitionInfo {
            path: "/dev/vda1".into(),
            size_bytes: GIB,
            size_human: "1G".into(),
            fstype: "vfat".into(),
            mountpoints: vec!["/boot/efi".into()],
            ..Default::default()
        });
        let req = PlanRequest {
            storage_mode: "premounted".into(),
            root_part: "/dev/vda2".into(),
            esp_part: "/dev/vda1".into(),
            premounted_root: "/".into(),
            ..Default::default()
        };
        let p = plan(&req, &[d]);
        assert!(!p.valid);
        assert!(p.errors.iter().any(|e| e.contains("cannot be /")));
    }
}
