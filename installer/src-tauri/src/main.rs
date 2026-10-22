#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod plan;

use plan::{
    human_bytes, plan as build_plan, valid_hostname, valid_locale, valid_password,
    valid_timezone, valid_username, DiskInfo, PartitionInfo, PlanRequest, StoragePlan,
    MIN_ROOT_BYTES, MIN_TOTAL_BYTES,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fmt;
use std::fs::{self, OpenOptions};
use std::io::{BufRead, BufReader, Read};
use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt, PermissionsExt};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;
use tauri::{AppHandle, Emitter, State};

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SystemInfo {
    pub uefi: bool,
    pub live: bool,
    pub memory_mib: u64,
    pub cpu: String,
    pub version: String,
    pub is_root: bool,
    pub engine_available: bool,
    pub engine_path: String,
    pub min_total_bytes: u64,
    pub min_total_human: String,
    pub min_root_human: String,
    pub disks: Vec<DiskInfo>,
    pub timezones: Vec<String>,
    pub keymaps: Vec<String>,
    pub locales: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
#[serde(default)]
pub struct InstallConfig {
    pub storage_mode: String,
    pub disk: String,
    pub esp_mode: String,
    pub esp_part: String,
    pub root_part: String,
    pub esp_mount: String,
    pub premounted_root: String,
    pub free_start: u64,
    pub free_end: u64,
    pub hostname: String,
    pub timezone: String,
    pub locale: String,
    pub kb_layout: String,
    pub user_name: String,
    pub user_sudo: String,
    pub user_password: String,
    pub root_password: String,
    pub extra_packages: String,
    pub mirror_source: String,
    pub mirror_region: String,
    pub driver_manifests: String,
    pub confirmed: bool,
}

#[derive(Clone, Debug, Serialize)]
pub struct StartResult {
    pub started: bool,
    pub engine: String,
    pub plan_file: String,
}

#[derive(Clone, Debug, Serialize)]
pub struct EngineStatus {
    pub available: bool,
    pub path: String,
    pub is_root: bool,
    pub live: bool,
}

#[derive(Clone, Debug, Serialize)]
pub struct LogLine {
    pub line: String,
    pub stream: String,
}

#[derive(Clone, Debug, Serialize)]
pub struct InstallFinished {
    pub code: Option<i32>,
    pub success: bool,
}

#[derive(Clone, Debug, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum InstallerError {
    Validation { message: String },
    Storage { message: String },
    Engine { message: String },
    Io { message: String },
    Busy { message: String },
}

impl fmt::Display for InstallerError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Validation { message }
            | Self::Storage { message }
            | Self::Engine { message }
            | Self::Io { message }
            | Self::Busy { message } => write!(f, "{message}"),
        }
    }
}

impl std::error::Error for InstallerError {}

impl From<std::io::Error> for InstallerError {
    fn from(value: std::io::Error) -> Self {
        Self::Io {
            message: value.to_string(),
        }
    }
}

impl From<serde_json::Error> for InstallerError {
    fn from(value: serde_json::Error) -> Self {
        Self::Validation {
            message: format!("invalid JSON: {value}"),
        }
    }
}

type Result<T> = std::result::Result<T, InstallerError>;

#[derive(Default)]
struct AppState {
    child: Mutex<Option<Arc<Mutex<Child>>>>,
}

impl From<&InstallConfig> for PlanRequest {
    fn from(c: &InstallConfig) -> Self {
        Self {
            storage_mode: c.storage_mode.clone(),
            disk: c.disk.clone(),
            esp_mode: c.esp_mode.clone(),
            esp_part: c.esp_part.clone(),
            root_part: c.root_part.clone(),
            esp_mount: c.esp_mount.clone(),
            premounted_root: c.premounted_root.clone(),
            free_start: c.free_start,
            free_end: c.free_end,
        }
    }
}

// ---------------------------------------------------------------------------
// System discovery (read-only)
// ---------------------------------------------------------------------------

fn command_output(program: &str, args: &[&str]) -> Option<String> {
    let output = Command::new(program).args(args).output().ok()?;
    if !output.status.success() {
        return None;
    }
    Some(String::from_utf8_lossy(&output.stdout).into_owned())
}

fn lsblk_value() -> Result<Value> {
    let columns = "NAME,KNAME,PATH,SIZE,TYPE,MODEL,TRAN,RM,FSTYPE,LABEL,MOUNTPOINTS,PTTYPE";
    let output = Command::new("lsblk")
        .args(["-J", "-b", "-o", columns])
        .output()?;
    if output.status.success() {
        return Ok(serde_json::from_slice(&output.stdout)?);
    }
    // util-linux distributions before 2.37 use MOUNTPOINT (singular).
    let output = Command::new("lsblk")
        .args([
            "-J", "-b", "-o", "NAME,KNAME,PATH,SIZE,TYPE,MODEL,TRAN,RM,FSTYPE,LABEL,MOUNTPOINT,PTTYPE",
        ])
        .output()?;
    if !output.status.success() {
        return Err(InstallerError::Storage {
            message: "lsblk failed; cannot inspect disks".into(),
        });
    }
    Ok(serde_json::from_slice(&output.stdout)?)
}

fn value_string(value: &Value, key: &str) -> String {
    value
        .get(key)
        .and_then(|v| v.as_str())
        .unwrap_or_default()
        .trim()
        .to_string()
}

fn value_u64(value: &Value, key: &str) -> u64 {
    value
        .get(key)
        .and_then(|v| {
            v.as_u64()
                .or_else(|| v.as_str().and_then(|s| s.trim().parse().ok()))
        })
        .unwrap_or(0)
}

fn value_bool(value: &Value, key: &str) -> bool {
    value
        .get(key)
        .and_then(|v| {
            v.as_bool().or_else(|| {
                v.as_str()
                    .map(|s| s == "1" || s.eq_ignore_ascii_case("true"))
            })
        })
        .unwrap_or(false)
}

fn mountpoints(value: &Value) -> Vec<String> {
    if let Some(items) = value.get("mountpoints").and_then(|v| v.as_array()) {
        return items
            .iter()
            .filter_map(|v| v.as_str())
            .filter(|s| !s.trim().is_empty())
            .map(str::to_string)
            .collect();
    }
    value
        .get("mountpoint")
        .and_then(|v| v.as_str())
        .filter(|s| !s.trim().is_empty())
        .map(|s| vec![s.to_string()])
        .unwrap_or_default()
}

fn live_parent_disk() -> Option<String> {
    let source = command_output("findmnt", &["-n", "-o", "SOURCE", "/run/archiso/bootmnt"])?;
    let source = source.trim();
    if source.is_empty() {
        return None;
    }
    let parent = command_output("lsblk", &["-no", "PKNAME", source])?;
    let parent = parent.trim();
    if parent.is_empty() {
        None
    } else {
        Some(format!("/dev/{parent}"))
    }
}

pub fn discover_disks() -> Result<Vec<DiskInfo>> {
    let value = lsblk_value()?;
    let live_parent = live_parent_disk();
    let mut disks = Vec::new();
    let Some(devices) = value.get("blockdevices").and_then(|v| v.as_array()) else {
        return Ok(disks);
    };
    for device in devices {
        if value_string(device, "type") != "disk" {
            continue;
        }
        let name = value_string(device, "name");
        if name.starts_with("loop")
            || name.starts_with("ram")
            || name.starts_with("zram")
            || name.starts_with("sr")
            || name.starts_with("dm-")
            || name.starts_with("md")
            || name.starts_with("nbd")
            || name.starts_with("rbd")
        {
            continue;
        }
        let path = {
            let p = value_string(device, "path");
            if p.is_empty() {
                format!("/dev/{name}")
            } else {
                p
            }
        };
        let mut partitions = Vec::new();
        if let Some(children) = device.get("children").and_then(|v| v.as_array()) {
            for child in children {
                if value_string(child, "type") != "part" {
                    continue;
                }
                let cname = value_string(child, "name");
                let cpath = {
                    let p = value_string(child, "path");
                    if p.is_empty() {
                        format!("/dev/{cname}")
                    } else {
                        p
                    }
                };
                partitions.push(PartitionInfo {
                    path: cpath,
                    size_bytes: value_u64(child, "size"),
                    size_human: human_bytes(value_u64(child, "size")),
                    fstype: value_string(child, "fstype"),
                    label: value_string(child, "label"),
                    mountpoints: mountpoints(child),
                    part_type: value_string(child, "parttype"),
                });
            }
        }
        let size = value_u64(device, "size");
        let live = live_parent.as_deref() == Some(path.as_str())
            || partitions
                .iter()
                .flat_map(|p| p.mountpoints.iter())
                .any(|m| m.starts_with("/run/archiso"));
        disks.push(DiskInfo {
            path,
            name,
            size_bytes: size,
            size_human: human_bytes(size),
            model: value_string(device, "model"),
            transport: value_string(device, "tran"),
            removable: value_bool(device, "rm"),
            pttype: value_string(device, "pttype"),
            is_live: live,
            partitions,
        });
    }
    disks.sort_by(|a, b| a.path.cmp(&b.path));
    Ok(disks)
}

fn read_first_line(path: &str, key: &str) -> String {
    let Ok(text) = fs::read_to_string(path) else {
        return String::new();
    };
    for line in text.lines() {
        if let Some(rest) = line.strip_prefix(key) {
            return rest.trim().to_string();
        }
    }
    String::new()
}

fn memory_mib() -> u64 {
    let Ok(text) = fs::read_to_string("/proc/meminfo") else {
        return 0;
    };
    for line in text.lines() {
        if let Some(rest) = line.strip_prefix("MemTotal:") {
            let kb = rest
                .split_whitespace()
                .next()
                .and_then(|s| s.parse::<u64>().ok())
                .unwrap_or(0);
            return kb / 1024;
        }
    }
    0
}

fn cpu_model() -> String {
    let value = read_first_line("/proc/cpuinfo", "model name");
    if value.is_empty() {
        "Unknown processor".into()
    } else {
        value
    }
}

fn is_root() -> bool {
    command_output("id", &["-u"])
        .and_then(|s| s.trim().parse::<u32>().ok())
        .is_some_and(|uid| uid == 0)
}

fn fallback_timezones() -> Vec<String> {
    let mut zones = vec![
        "UTC".to_string(),
        "Europe/Berlin".to_string(),
        "Europe/London".to_string(),
        "Europe/Paris".to_string(),
        "America/New_York".to_string(),
        "America/Chicago".to_string(),
        "America/Los_Angeles".to_string(),
        "Asia/Tokyo".to_string(),
        "Asia/Shanghai".to_string(),
        "Australia/Sydney".to_string(),
    ];
    zones.sort();
    zones.dedup();
    zones
}

fn timezones() -> Vec<String> {
    if let Some(output) = command_output("timedatectl", &["list-timezones"]) {
        let mut zones: Vec<String> = output
            .lines()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(str::to_string)
            .collect();
        if !zones.is_empty() {
            zones.sort();
            zones.dedup();
            return zones;
        }
    }
    if let Ok(text) = fs::read_to_string("/usr/share/zoneinfo/zone.tab") {
        let mut zones: Vec<String> = text
            .lines()
            .filter(|l| !l.starts_with('#') && !l.trim().is_empty())
            .filter_map(|l| l.split_whitespace().nth(2))
            .map(str::to_string)
            .collect();
        if !zones.is_empty() {
            zones.sort();
            zones.dedup();
            return zones;
        }
    }
    fallback_timezones()
}

fn keymaps() -> Vec<String> {
    if let Some(output) = command_output("localectl", &["list-keymaps"]) {
        let mut keys: Vec<String> = output
            .lines()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(str::to_string)
            .collect();
        if !keys.is_empty() {
            keys.sort();
            keys.dedup();
            return keys;
        }
    }
    ["us", "uk", "de", "fr", "es", "it", "br", "ru", "jp", "cn"]
        .iter()
        .map(|s| s.to_string())
        .collect()
}

fn locales() -> Vec<String> {
    [
        "en_US.UTF-8",
        "en_GB.UTF-8",
        "de_DE.UTF-8",
        "fr_FR.UTF-8",
        "es_ES.UTF-8",
        "it_IT.UTF-8",
        "pt_BR.UTF-8",
        "ru_RU.UTF-8",
        "ja_JP.UTF-8",
        "zh_CN.UTF-8",
        "C.UTF-8",
    ]
    .iter()
    .map(|s| s.to_string())
    .collect()
}

fn state_dir() -> PathBuf {
    std::env::var_os("ASTRA_STATE_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/run/astra-install"))
}

fn engine_path() -> Option<PathBuf> {
    if let Some(value) = std::env::var_os("ASTRA_ENGINE") {
        let path = PathBuf::from(value);
        if path.is_file() {
            return Some(path);
        }
        return None;
    }
    ["/usr/lib/astra/installer/astra-engine", "/usr/bin/astra-installer-engine"]
        .iter()
        .map(PathBuf::from)
        .find(|p| p.is_file())
}

fn engine_available() -> bool {
    engine_path().is_some()
}

fn collect_system_info() -> Result<SystemInfo> {
    Ok(SystemInfo {
        uefi: Path::new("/sys/firmware/efi").exists(),
        live: Path::new("/run/archiso/bootmnt").exists(),
        memory_mib: memory_mib(),
        cpu: cpu_model(),
        version: env!("CARGO_PKG_VERSION").to_string(),
        is_root: is_root(),
        engine_available: engine_available(),
        engine_path: engine_path()
            .map(|p| p.display().to_string())
            .unwrap_or_else(|| "not installed".into()),
        min_total_bytes: MIN_TOTAL_BYTES,
        min_total_human: human_bytes(MIN_TOTAL_BYTES),
        min_root_human: human_bytes(MIN_ROOT_BYTES),
        disks: discover_disks()?,
        timezones: timezones(),
        keymaps: keymaps(),
        locales: locales(),
    })
}

// ---------------------------------------------------------------------------
// Validation and plan/install commands
// ---------------------------------------------------------------------------

fn validate_config(c: &InstallConfig) -> Vec<String> {
    let mut errors = Vec::new();
    if !c.confirmed {
        errors.push("Confirm the destructive action before installing.".into());
    }
    if !valid_hostname(&c.hostname) {
        errors.push("Hostname must be 1-63 letters, digits or hyphens.".into());
    }
    if !valid_username(&c.user_name) {
        errors.push("Username must start with a lowercase letter or underscore.".into());
    }
    if !valid_timezone(&c.timezone) {
        errors.push("Choose a valid IANA timezone.".into());
    }
    if !valid_locale(&c.locale) {
        errors.push("Choose a valid UTF-8 locale.".into());
    }
    if c.kb_layout.trim().is_empty()
        || !c
            .kb_layout
            .chars()
            .all(|ch| ch.is_ascii_alphanumeric() || ch == '_' || ch == '-')
    {
        errors.push("Keyboard layout is invalid.".into());
    }
    if !valid_password(&c.root_password) {
        errors.push("The root password cannot be empty or contain a newline.".into());
    }
    if !valid_password(&c.user_password) {
        errors.push("The user password cannot be empty or contain a newline.".into());
    }
    if !matches!(c.user_sudo.as_str(), "passwordless" | "with-password" | "none") {
        errors.push("Sudo mode is invalid.".into());
    }
    if !matches!(c.storage_mode.as_str(), "whole" | "free" | "manual" | "premounted") {
        errors.push("Choose a storage mode.".into());
    }
    if !matches!(c.mirror_source.as_str(), "" | "ala" | "mirrors") {
        errors.push("Package source is invalid.".into());
    }
    if c.mirror_source == "mirrors" && c.mirror_region.trim().is_empty() {
        errors.push("Choose a mirror region.".into());
    }
    for pkg in c.extra_packages.split(',') {
        let pkg = pkg.trim();
        if pkg.is_empty() {
            continue;
        }
        if !pkg
            .chars()
            .all(|ch| ch.is_ascii_alphanumeric() || "@._+-".contains(ch))
        {
            errors.push(format!("Invalid extra package name: {pkg}"));
        }
    }
    errors
}

fn plan_request(c: &InstallConfig) -> PlanRequest {
    PlanRequest::from(c)
}

fn write_plan_file(config: &InstallConfig) -> Result<PathBuf> {
    let dir = state_dir();
    fs::DirBuilder::new()
        .recursive(true)
        .mode(0o700)
        .create(&dir)?;
    let path = dir.join("plan.json");
    let mut file = OpenOptions::new()
        .create(true)
        .write(true)
        .truncate(true)
        .mode(0o600)
        .open(&path)?;
    serde_json::to_writer(&mut file, config)?;
    fs::set_permissions(&path, fs::Permissions::from_mode(0o600))?;
    Ok(path)
}

#[tauri::command]
fn system_info() -> Result<SystemInfo> {
    collect_system_info()
}

#[tauri::command]
fn plan_storage(req: PlanRequest) -> Result<StoragePlan> {
    let disks = discover_disks()?;
    Ok(build_plan(&req, &disks))
}

#[tauri::command]
fn engine_status() -> EngineStatus {
    EngineStatus {
        available: engine_available(),
        path: engine_path()
            .map(|p| p.display().to_string())
            .unwrap_or_else(|| "not installed".into()),
        is_root: is_root(),
        live: Path::new("/run/archiso/bootmnt").exists(),
    }
}

#[tauri::command]
fn start_install(
    app: AppHandle,
    state: State<'_, AppState>,
    config: InstallConfig,
) -> Result<StartResult> {
    let errors = validate_config(&config);
    if !errors.is_empty() {
        return Err(InstallerError::Validation {
            message: errors.join(" "),
        });
    }
    let disks = discover_disks()?;
    let storage = build_plan(&plan_request(&config), &disks);
    if !storage.valid {
        return Err(InstallerError::Storage {
            message: storage.errors.join(" "),
        });
    }

    let mut slot = state.child.lock().expect("installer child lock");
    if let Some(previous) = slot.as_ref() {
        let mut child = previous.lock().expect("installer child lock");
        if child.try_wait().ok().flatten().is_none() {
            return Err(InstallerError::Busy {
                message: "An installation is already running.".into(),
            });
        }
    }
    *slot = None;

    let engine = engine_path().ok_or_else(|| InstallerError::Engine {
        message: "The AstraOS install engine is not installed.".into(),
    })?;
    let plan_file = write_plan_file(&config)?;
    let mut child = Command::new(&engine)
        .arg(&plan_file)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| InstallerError::Engine {
            message: format!("Could not start {}: {e}", engine.display()),
        })?;

    let stdout = child.stdout.take();
    let stderr = child.stderr.take();
    if let Some(stdout) = stdout {
        pump(app.clone(), "stdout", stdout);
    }
    if let Some(stderr) = stderr {
        pump(app.clone(), "stderr", stderr);
    }

    let child = Arc::new(Mutex::new(child));
    *slot = Some(child.clone());
    drop(slot);

    let app_for_monitor = app.clone();
    thread::spawn(move || loop {
        let status = {
            let mut guard = child.lock().expect("installer child lock");
            guard.try_wait().ok().flatten()
        };
        if let Some(status) = status {
            let code = status.code();
            let _ = app_for_monitor.emit(
                "install-finished",
                InstallFinished {
                    code,
                    success: status.success(),
                },
            );
            break;
        }
        thread::sleep(Duration::from_millis(300));
    });

    let _ = app.emit("install-started", ());
    Ok(StartResult {
        started: true,
        engine: engine.display().to_string(),
        plan_file: plan_file.display().to_string(),
    })
}

fn pump<R: Read + Send + 'static>(app: AppHandle, stream: &'static str, reader: R) {
    thread::spawn(move || {
        let reader = BufReader::new(reader);
        for line in reader.lines() {
            match line {
                Ok(line) => {
                    let _ = app.emit(
                        "install-log",
                        LogLine {
                            line,
                            stream: stream.to_string(),
                        },
                    );
                }
                Err(_) => break,
            }
        }
    });
}

#[tauri::command]
fn cancel_install(state: State<'_, AppState>) -> Result<()> {
    let slot = state.child.lock().expect("installer child lock");
    if let Some(child) = slot.as_ref() {
        let mut child = child.lock().expect("installer child lock");
        let _ = child.kill();
    }
    Ok(())
}

#[tauri::command]
fn read_log() -> String {
    let path = state_dir().join("install.log");
    let Ok(text) = fs::read_to_string(path) else {
        return String::new();
    };
    let mut lines: Vec<&str> = text.lines().rev().take(160).collect();
    lines.reverse();
    lines.join("\n")
}

#[tauri::command]
fn reboot_system() -> Result<()> {
    Command::new("systemctl")
        .arg("reboot")
        .spawn()
        .map_err(|e| InstallerError::Io {
            message: format!("could not reboot: {e}"),
        })?;
    Ok(())
}

// ---------------------------------------------------------------------------
// CLI mode: same Rust validation and engine path, useful for automated VM tests
// ---------------------------------------------------------------------------

fn read_config(path: &str) -> Result<InstallConfig> {
    let text = fs::read_to_string(path)?;
    Ok(serde_json::from_str(&text)?)
}

fn run_engine_cli(config: &InstallConfig) -> Result<i32> {
    let errors = validate_config(config);
    if !errors.is_empty() {
        return Err(InstallerError::Validation {
            message: errors.join(" "),
        });
    }
    let disks = discover_disks()?;
    let storage = build_plan(&plan_request(config), &disks);
    if !storage.valid {
        return Err(InstallerError::Storage {
            message: storage.errors.join(" "),
        });
    }
    let engine = engine_path().ok_or_else(|| InstallerError::Engine {
        message: "The AstraOS install engine is not installed.".into(),
    })?;
    let plan_file = write_plan_file(config)?;
    let status = Command::new(&engine)
        .arg(&plan_file)
        .stdin(Stdio::null())
        .status()
        .map_err(|e| InstallerError::Engine {
            message: format!("Could not start {}: {e}", engine.display()),
        })?;
    Ok(status.code().unwrap_or(1))
}

fn print_plan(path: &str) -> Result<()> {
    let config = read_config(path)?;
    let disks = discover_disks()?;
    let plan = build_plan(&plan_request(&config), &disks);
    println!("{}", serde_json::to_string_pretty(&plan)?);
    if plan.valid {
        Ok(())
    } else {
        Err(InstallerError::Storage {
            message: plan.errors.join(" "),
        })
    }
}

fn cli() -> Option<i32> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        return None;
    }
    match args[1].as_str() {
        "--version" => {
            println!("astra-installer {}", env!("CARGO_PKG_VERSION"));
            Some(0)
        }
        "--help" => {
            println!(
                "AstraOS installer\n\n\
                 GUI:             astra-installer\n\
                 JSON plan:       astra-installer --plan-json <answers.json>\n\
                 Install:         astra-installer --install-json <answers.json>\n\
                 Version:         astra-installer --version\n"
            );
            Some(0)
        }
        "--plan-json" => {
            let Some(path) = args.get(2) else {
                eprintln!("--plan-json requires a file");
                return Some(2);
            };
            match print_plan(path) {
                Ok(()) => Some(0),
                Err(error) => {
                    eprintln!("{error}");
                    Some(1)
                }
            }
        }
        "--install-json" => {
            let Some(path) = args.get(2) else {
                eprintln!("--install-json requires a file");
                return Some(2);
            };
            let result = read_config(path).and_then(|config| run_engine_cli(&config));
            match result {
                Ok(code) => Some(code),
                Err(error) => {
                    eprintln!("{error}");
                    Some(1)
                }
            }
        }
        _ => {
            eprintln!("unknown argument: {} (try --help)", args[1]);
            Some(2)
        }
    }
}

fn main() {
    if let Some(code) = cli() {
        std::process::exit(code);
    }

    tauri::Builder::default()
        .manage(AppState::default())
        .invoke_handler(tauri::generate_handler![
            system_info,
            plan_storage,
            engine_status,
            start_install,
            cancel_install,
            read_log,
            reboot_system
        ])
        .run(tauri::generate_context!())
        .expect("error while running the AstraOS installer");
}
