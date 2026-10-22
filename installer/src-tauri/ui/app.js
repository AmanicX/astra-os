/**
 * AstraOS Installer — Frontend Application Logic
 * Integrates with Tauri 2 commands and events.
 */

// ---------------------------------------------------------------------------
// Tauri IPC Wrapper & Fallback Support
// ---------------------------------------------------------------------------

const tauriCore = window.__TAURI__?.core;
const tauriEvent = window.__TAURI__?.event;

async function invokeTauri(cmd, args = {}) {
  if (tauriCore && typeof tauriCore.invoke === 'function') {
    return await tauriCore.invoke(cmd, args);
  }
  console.warn(`[Tauri Mock] Invoke '${cmd}' with:`, args);
  
  // Standalone browser / test mock fallbacks
  if (cmd === 'system_info') {
    return {
      uefi: true,
      live: true,
      memory_mib: 8192,
      cpu: 'AMD Ryzen 7 / Intel Core i7 (Virtual CPU)',
      version: '0.2.0',
      is_root: true,
      engine_available: true,
      engine_path: '/usr/bin/astra-engine',
      min_total_bytes: 35 * 1024 * 1024 * 1024,
      min_total_human: '35.0 GiB',
      min_root_human: '34.0 GiB',
      disks: [
        {
          path: '/dev/vda',
          name: 'vda',
          size_bytes: 40 * 1024 * 1024 * 1024,
          size_human: '40.0 GiB',
          model: 'QEMU VIRTIO DISK',
          transport: 'virtio',
          removable: false,
          pttype: 'gpt',
          is_live: false,
          partitions: []
        }
      ],
      timezones: ['UTC', 'Europe/Berlin', 'Europe/London', 'America/New_York', 'Asia/Tokyo'],
      keymaps: ['us', 'uk', 'de', 'fr', 'es', 'it'],
      locales: ['en_US.UTF-8', 'en_GB.UTF-8', 'de_DE.UTF-8', 'C.UTF-8']
    };
  }
  if (cmd === 'plan_storage') {
    return {
      valid: true,
      errors: [],
      warnings: ['This is destructive: all data on the disk will be lost.'],
      steps: [
        'Erase every partition on /dev/vda',
        'Create a 1 GiB EFI system partition (type EF00)',
        'Create a 39.0 GiB Btrfs root partition (type 8300)',
        'Format the ESP as FAT32 and the root as Btrfs',
        'Install AstraOS packages and SilentSDDM desktop'
      ],
      storage_mode: args.req?.storage_mode || 'whole',
      disk: args.req?.disk || '/dev/vda',
      disk_size_bytes: 40 * 1024 * 1024 * 1024,
      disk_size_human: '40.0 GiB',
      total_bytes: 40 * 1024 * 1024 * 1024,
      total_human: '40.0 GiB',
      minimum_bytes: 35 * 1024 * 1024 * 1024,
      minimum_human: '35.0 GiB',
      destroy_disk: true,
      esp: {
        role: 'esp',
        device: '/dev/vda1',
        size_bytes: 1024 * 1024 * 1024,
        size_human: '1.0 GiB',
        filesystem: 'vfat',
        mountpoint: '/boot/efi',
        source: 'new'
      },
      root: {
        role: 'root',
        device: '/dev/vda2',
        size_bytes: 39 * 1024 * 1024 * 1024,
        size_human: '39.0 GiB',
        filesystem: 'btrfs',
        mountpoint: '/',
        source: 'new'
      }
    };
  }
  if (cmd === 'start_install') {
    setTimeout(() => {
      document.dispatchEvent(new CustomEvent('mock-log', { detail: { line: 'Starting pacstrap...', stream: 'stdout' } }));
      setTimeout(() => {
        document.dispatchEvent(new CustomEvent('mock-log', { detail: { line: 'Installing packages to target root...', stream: 'stdout' } }));
      }, 1000);
    }, 500);
    return { started: true, engine: '/usr/bin/astra-engine', plan_file: '/run/astra-install/plan.json' };
  }
  if (cmd === 'cancel_install') return null;
  if (cmd === 'read_log') return 'Installation completed successfully.';
  if (cmd === 'reboot_system') {
    alert('Reboot requested.');
    return null;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Application State
// ---------------------------------------------------------------------------

const state = {
  currentStep: 'welcome',
  systemInfo: null,
  currentPlan: null,
  autoscroll: true,
  passwordsVisible: false,
  
  // Canonical form configuration
  config: {
    storage_mode: 'whole',
    disk: '',
    esp_mode: 'new',
    esp_part: '',
    root_part: '',
    esp_mount: '/boot/efi',
    premounted_root: '/mnt',
    free_start: 2048,
    free_end: 0,
    hostname: 'astraos',
    timezone: 'UTC',
    locale: 'en_US.UTF-8',
    kb_layout: 'us',
    user_name: 'astra',
    user_sudo: 'passwordless',
    user_password: '',
    root_password: '',
    extra_packages: '',
    mirror_source: 'ala',
    mirror_region: 'Worldwide',
    driver_manifests: '',
    confirmed: false
  }
};

const STEP_ORDER = ['welcome', 'locale', 'storage', 'account', 'options', 'summary', 'progress', 'finish'];

// ---------------------------------------------------------------------------
// Step Navigation Management
// ---------------------------------------------------------------------------

function setStep(stepName) {
  if (!STEP_ORDER.includes(stepName)) return;
  
  // Validation guard before advancing to summary or progress
  if (stepName === 'summary' || stepName === 'account') {
    if (!validateStorageStep()) return;
  }
  if (stepName === 'options' || stepName === 'summary') {
    if (!validateAccountStep()) return;
  }
  
  state.currentStep = stepName;
  
  // Update view visibility
  document.querySelectorAll('.wizard-page').forEach(page => {
    page.classList.remove('active');
  });
  const targetPage = document.getElementById(`page-${stepName}`);
  if (targetPage) targetPage.classList.add('active');
  
  // Update sidebar navigation items
  const currentIndex = STEP_ORDER.indexOf(stepName);
  document.querySelectorAll('.nav-step').forEach(btn => {
    const btnStep = btn.dataset.step;
    const btnIndex = STEP_ORDER.indexOf(btnStep);
    
    btn.classList.remove('active', 'completed');
    if (btnStep === stepName) {
      btn.classList.add('active');
    } else if (btnIndex < currentIndex) {
      btn.classList.add('completed');
    }
  });

  // Page-specific activation hooks
  if (stepName === 'storage') {
    triggerPlanUpdate();
  } else if (stepName === 'summary') {
    populateSummary();
  }
}

// ---------------------------------------------------------------------------
// System Info & Hardware Detection
// ---------------------------------------------------------------------------

async function initSystemInfo() {
  try {
    const info = await invokeTauri('system_info');
    state.systemInfo = info;
    
    // Populate Welcome Page
    const valUefi = document.getElementById('val-uefi');
    const badgeUefi = document.getElementById('badge-uefi');
    if (info.uefi) {
      valUefi.textContent = 'UEFI (x86_64)';
      badgeUefi.textContent = 'Supported';
      badgeUefi.className = 'status-badge status-ok';
    } else {
      valUefi.textContent = 'Legacy BIOS / CSM';
      badgeUefi.textContent = 'Unsupported';
      badgeUefi.className = 'status-badge status-err';
      document.getElementById('welcome-uefi-alert').classList.remove('hidden');
      document.getElementById('btn-welcome-begin').disabled = true;
    }

    const valRoot = document.getElementById('val-root');
    const badgeRoot = document.getElementById('badge-root');
    if (info.is_root) {
      valRoot.textContent = 'root (UID 0)';
      badgeRoot.textContent = 'Privileged';
      badgeRoot.className = 'status-badge status-ok';
    } else {
      valRoot.textContent = 'Unprivileged user';
      badgeRoot.textContent = 'Root required';
      badgeRoot.className = 'status-badge status-err';
      document.getElementById('welcome-root-alert').classList.remove('hidden');
    }

    document.getElementById('val-cpu').textContent = info.cpu || 'x86_64 Processor';
    document.getElementById('val-ram').textContent = `${(info.memory_mib / 1024).toFixed(1)} GiB`;
    
    const badgeEngine = document.getElementById('badge-engine');
    if (info.engine_available) {
      badgeEngine.textContent = 'Ready';
      badgeEngine.className = 'status-badge status-ok';
    } else {
      badgeEngine.textContent = 'Missing';
      badgeEngine.className = 'status-badge status-warn';
    }
    
    if (info.version) {
      document.getElementById('sidebar-version').textContent = `v${info.version} • Live Installer`;
    }

    // Populate Localization Page
    populateSelect('select-keymap', info.keymaps, state.config.kb_layout);
    populateSelect('select-timezone', info.timezones, state.config.timezone);
    populateSelect('select-locale', info.locales, state.config.locale);

    // Populate Disks & Storage Options
    renderDiskList(info.disks);
    
  } catch (err) {
    console.error('Failed to load system info:', err);
  }
}

function populateSelect(elemId, items, selectedValue) {
  const sel = document.getElementById(elemId);
  if (!sel || !items) return;
  sel.innerHTML = '';
  
  items.forEach(item => {
    const opt = document.createElement('option');
    opt.value = item;
    opt.textContent = item;
    if (item === selectedValue) opt.selected = true;
    sel.appendChild(opt);
  });
}

function setupFilterableSelect(inputId, selectId) {
  const input = document.getElementById(inputId);
  const select = document.getElementById(selectId);
  if (!input || !select) return;
  
  input.addEventListener('input', () => {
    const filter = input.value.toLowerCase().trim();
    Array.from(select.options).forEach(opt => {
      const match = opt.text.toLowerCase().includes(filter);
      opt.style.display = match ? '' : 'none';
    });
  });
}

// ---------------------------------------------------------------------------
// Storage & Disk Planning Logic (Read-Only)
// ---------------------------------------------------------------------------

function renderDiskList(disks) {
  const container = document.getElementById('disk-list');
  const countEl = document.getElementById('disk-count');
  if (!container) return;
  
  container.innerHTML = '';
  countEl.textContent = `${disks.length} device${disks.length === 1 ? '' : 's'}`;
  
  if (disks.length === 0) {
    container.innerHTML = '<div class="empty-state">No block devices detected.</div>';
    return;
  }
  
  let hasSelected = false;
  
  disks.forEach(d => {
    const card = document.createElement('div');
    card.className = 'disk-card';
    if (d.is_live) card.classList.add('disabled');
    
    // Auto-select first non-live disk if none selected
    if (!hasSelected && !d.is_live) {
      card.classList.add('selected');
      state.config.disk = d.path;
      hasSelected = true;
    }
    
    card.innerHTML = `
      <div class="disk-main-info">
        <div class="disk-path-row">
          <span class="disk-path">${d.path}</span>
          ${d.is_live ? '<span class="disk-tag tag-live">Live Medium</span>' : ''}
          ${d.removable ? '<span class="disk-tag">Removable</span>' : ''}
          <span class="disk-tag">${d.pttype || 'unpartitioned'}</span>
        </div>
        <span class="disk-model">${d.model || 'Block Device'} • ${d.transport || 'internal'}</span>
      </div>
      <div class="disk-size">${d.size_human}</div>
    `;
    
    if (!d.is_live) {
      card.addEventListener('click', () => {
        container.querySelectorAll('.disk-card').forEach(c => c.classList.remove('selected'));
        card.classList.add('selected');
        state.config.disk = d.path;
        triggerPlanUpdate();
      });
    }
    
    container.appendChild(card);
  });
  
  // Populate partition selectors for manual/free/premounted modes
  updatePartitionSelects(disks);
}

function updatePartitionSelects(disks) {
  const manualRoot = document.getElementById('select-manual-root');
  const manualEsp = document.getElementById('select-manual-esp');
  const freeEsp = document.getElementById('select-free-esp');
  const premountedRoot = document.getElementById('select-premounted-root');
  const premountedEsp = document.getElementById('select-premounted-esp');
  
  const allParts = [];
  disks.forEach(d => {
    (d.partitions || []).forEach(p => {
      allParts.push({ disk: d.path, ...p });
    });
  });
  
  [manualRoot, manualEsp, freeEsp, premountedRoot, premountedEsp].forEach(sel => {
    if (!sel) return;
    sel.innerHTML = '<option value="">-- Choose Partition --</option>';
    allParts.forEach(p => {
      const opt = document.createElement('option');
      opt.value = p.path;
      opt.textContent = `${p.path} (${p.size_human}${p.fstype ? ', ' + p.fstype : ''})`;
      sel.appendChild(opt);
    });
  });
}

async function triggerPlanUpdate() {
  const req = {
    storage_mode: state.config.storage_mode,
    disk: state.config.disk,
    esp_mode: state.config.esp_mode,
    esp_part: state.config.esp_part,
    root_part: state.config.root_part,
    esp_mount: state.config.esp_mount,
    premounted_root: state.config.premounted_root,
    free_start: Number(state.config.free_start) || 2048,
    free_end: Number(state.config.free_end) || 0
  };
  
  try {
    const plan = await invokeTauri('plan_storage', { req });
    state.currentPlan = plan;
    renderStoragePlan(plan);
  } catch (err) {
    console.error('Plan calculation error:', err);
  }
}

function renderStoragePlan(plan) {
  const badge = document.getElementById('plan-status-badge');
  const btnNext = document.getElementById('btn-storage-next');
  const diskSize = document.getElementById('plan-disk-size');
  const allocSize = document.getElementById('plan-alloc-size');
  const stepsList = document.getElementById('plan-steps-list');
  const warnBox = document.getElementById('plan-warnings-box');
  const warnContent = document.getElementById('plan-warnings-content');
  const errBox = document.getElementById('plan-errors-box');
  const errContent = document.getElementById('plan-errors-content');
  
  diskSize.textContent = plan.disk_size_human || '--';
  allocSize.textContent = plan.total_human || '--';
  
  // Status Badge
  if (plan.valid) {
    badge.textContent = 'Plan Valid';
    badge.className = 'status-badge status-ok';
    btnNext.disabled = false;
  } else {
    badge.textContent = 'Invalid Layout';
    badge.className = 'status-badge status-err';
    btnNext.disabled = true;
  }
  
  // Steps List
  stepsList.innerHTML = '';
  (plan.steps || []).forEach(step => {
    const li = document.createElement('li');
    li.textContent = step;
    stepsList.appendChild(li);
  });
  
  // Warnings Box
  if (plan.warnings && plan.warnings.length > 0) {
    warnBox.classList.remove('hidden');
    warnContent.innerHTML = plan.warnings.join('<br>');
  } else {
    warnBox.classList.add('hidden');
  }
  
  // Errors Box
  if (plan.errors && plan.errors.length > 0) {
    errBox.classList.remove('hidden');
    errContent.innerHTML = plan.errors.join('<br>');
  } else {
    errBox.classList.add('hidden');
  }
  
  // Partition Bar Visual Preview
  const espSegment = document.getElementById('visual-esp');
  const rootSegment = document.getElementById('visual-root');
  if (plan.valid && plan.esp && plan.root) {
    const total = (plan.esp.size_bytes || 0) + (plan.root.size_bytes || 0);
    if (total > 0) {
      const espPct = Math.max(12, Math.min(25, (plan.esp.size_bytes / total) * 100));
      const rootPct = 100 - espPct;
      espSegment.style.width = `${espPct}%`;
      espSegment.querySelector('.segment-label').textContent = `ESP (${plan.esp.size_human})`;
      rootSegment.style.width = `${rootPct}%`;
      rootSegment.querySelector('.segment-label').textContent = `Root Btrfs (${plan.root.size_human})`;
    }
  }
}

function validateStorageStep() {
  if (!state.currentPlan || !state.currentPlan.valid) {
    alert('Please resolve storage plan errors before proceeding.');
    return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Account Validation & Data Binding
// ---------------------------------------------------------------------------

function validateHostname(name) {
  const s = name.trim();
  return s.length >= 1 && s.length <= 63 &&
    /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/.test(s);
}

function validateUsername(name) {
  const s = name.trim();
  return s.length >= 1 && s.length <= 32 && s !== 'root' &&
    /^[a-z_][a-z0-9_-]*$/.test(s);
}

function validateAccountStep() {
  const errBox = document.getElementById('account-error-box');
  const errText = document.getElementById('account-error-text');
  const errors = [];
  
  state.config.hostname = document.getElementById('input-hostname').value.trim();
  state.config.user_name = document.getElementById('input-username').value.trim();
  state.config.user_password = document.getElementById('input-user-pw').value;
  const userConfirm = document.getElementById('input-user-pw-confirm').value;
  
  const sameRoot = document.getElementById('chk-same-root-pw').checked;
  if (sameRoot) {
    state.config.root_password = state.config.user_password;
  } else {
    state.config.root_password = document.getElementById('input-root-pw').value;
  }
  const rootConfirm = sameRoot ? userConfirm : document.getElementById('input-root-pw-confirm').value;
  
  if (!validateHostname(state.config.hostname)) {
    errors.push('Hostname must be 1-63 alphanumeric characters or hyphens (cannot start or end with a hyphen).');
  }
  
  if (!validateUsername(state.config.user_name)) {
    errors.push('Username must start with a lowercase letter or underscore, cannot be "root", and must be at most 32 characters.');
  }
  
  if (!state.config.user_password) {
    errors.push('User password cannot be empty.');
  } else if (state.config.user_password.includes('\n') || state.config.user_password.includes('\r')) {
    errors.push('Password cannot contain newlines.');
  }
  
  if (state.config.user_password !== userConfirm) {
    errors.push('User passwords do not match.');
  }
  
  if (!state.config.root_password) {
    errors.push('Root password cannot be empty.');
  } else if (state.config.root_password.includes('\n') || state.config.root_password.includes('\r')) {
    errors.push('Root password cannot contain newlines.');
  }
  
  if (!sameRoot && state.config.root_password !== rootConfirm) {
    errors.push('Root passwords do not match.');
  }
  
  if (errors.length > 0) {
    errBox.classList.remove('hidden');
    errText.innerHTML = errors.join('<br>');
    return false;
  }
  
  errBox.classList.add('hidden');
  return true;
}

// ---------------------------------------------------------------------------
// Summary Review & Confirmation
// ---------------------------------------------------------------------------

function populateSummary() {
  document.getElementById('sum-mode').textContent = state.config.storage_mode.toUpperCase();
  document.getElementById('sum-disk').textContent = state.config.disk;
  
  if (state.currentPlan) {
    const esp = state.currentPlan.esp;
    const root = state.currentPlan.root;
    document.getElementById('sum-esp').textContent = `${esp.device} (${esp.size_human}, ${esp.filesystem})`;
    document.getElementById('sum-root').textContent = `${root.device} (${root.size_human}, ${root.filesystem} @, @home, @snapshots)`;
  }
  
  document.getElementById('sum-hostname').textContent = state.config.hostname;
  document.getElementById('sum-username').textContent = state.config.user_name;
  document.getElementById('sum-sudo').textContent = 
    state.config.user_sudo === 'passwordless' ? 'Passwordless Sudo (%wheel NOPASSWD)' :
    state.config.user_sudo === 'with-password' ? 'Sudo with Password' : 'No Sudo (Root only)';
  document.getElementById('sum-locale-tz').textContent = `${state.config.locale} • ${state.config.timezone}`;
  
  // Dynamic impact description
  const impactErase = document.getElementById('sum-impact-erase');
  if (state.config.storage_mode === 'whole') {
    impactErase.textContent = `All existing partitions and data on ${state.config.disk} will be permanently erased.`;
  } else if (state.config.storage_mode === 'manual') {
    impactErase.textContent = `Partition ${state.config.root_part} will be formatted. EFI partition ${state.config.esp_part} will be preserved.`;
  } else if (state.config.storage_mode === 'free') {
    impactErase.textContent = `Only sectors ${state.config.free_start}-${state.config.free_end} on ${state.config.disk} will be modified.`;
  } else {
    impactErase.textContent = `Pre-mounted filesystems under ${state.config.premounted_root} will be configured.`;
  }
  
  // Reset confirmation checkbox
  const chk = document.getElementById('chk-confirm');
  chk.checked = false;
  state.config.confirmed = false;
  document.getElementById('btn-install').disabled = true;
}

// ---------------------------------------------------------------------------
// Installation Execution & Streamed Logs
// ---------------------------------------------------------------------------

async function startInstallation() {
  state.config.confirmed = document.getElementById('chk-confirm').checked;
  if (!state.config.confirmed) return;
  
  setStep('progress');
  
  const terminalContent = document.getElementById('terminal-content');
  terminalContent.textContent = '>> Starting privileged AstraOS install engine...\n';
  
  try {
    const result = await invokeTauri('start_install', { config: state.config });
    appendLogLine(`[INIT] Engine started: ${result.engine}`, 'stdout');
    appendLogLine(`[INIT] Plan written to: ${result.plan_file} (mode 0600, will be deleted by engine)`, 'stdout');
  } catch (err) {
    appendLogLine(`[ERROR] Start failure: ${err.message || err}`, 'stderr');
    showInstallFinished(1, false, err.message || String(err));
  }
}

function appendLogLine(line, stream = 'stdout') {
  const terminalContent = document.getElementById('terminal-content');
  const viewport = document.getElementById('terminal-viewport');
  if (!terminalContent) return;
  
  const lineEl = document.createElement('div');
  lineEl.className = stream === 'stderr' ? 'log-line-stderr' : 'log-line-stdout';
  lineEl.textContent = line;
  terminalContent.appendChild(lineEl);
  
  if (state.autoscroll && viewport) {
    viewport.scrollTop = viewport.scrollHeight;
  }
  
  // Dynamic phase title update based on known engine log patterns
  const phaseTitle = document.getElementById('progress-phase-title');
  const phaseDesc = document.getElementById('progress-phase-desc');
  if (line.includes('partition') || line.includes('sgdisk')) {
    phaseTitle.textContent = 'Preparing Storage Partitions...';
    phaseDesc.textContent = 'Creating GPT partition table and formatting filesystems.';
  } else if (line.includes('btrfs') || line.includes('subvolume')) {
    phaseTitle.textContent = 'Creating Btrfs Layout...';
    phaseDesc.textContent = 'Setting up subvolumes (@, @home, @snapshots, @pkg, @log).';
  } else if (line.includes('pacstrap')) {
    phaseTitle.textContent = 'Installing System Packages...';
    phaseDesc.textContent = 'Pacstrapping AstraOS base packages and desktop components.';
  } else if (line.includes('grub') || line.includes('bootloader')) {
    phaseTitle.textContent = 'Installing UEFI Bootloader...';
    phaseDesc.textContent = 'Configuring GRUB and generating initramfs with mkinitcpio.';
  } else if (line.includes('SilentSDDM') || line.includes('sddm')) {
    phaseTitle.textContent = 'Configuring Desktop Session...';
    phaseDesc.textContent = 'Applying SilentSDDM presets and AstraOS branding.';
  }
}

function showInstallFinished(code, success, errorMsg = '') {
  setStep('finish');
  
  const successBox = document.getElementById('finish-success');
  const failureBox = document.getElementById('finish-failure');
  
  if (success) {
    successBox.classList.remove('hidden');
    failureBox.classList.add('hidden');
  } else {
    successBox.classList.add('hidden');
    failureBox.classList.remove('hidden');
    
    document.getElementById('fail-error-detail').textContent = 
      errorMsg || `Process exited with non-zero exit code: ${code}`;
    
    // Fetch last 160 lines via read_log command
    invokeTauri('read_log').then(log => {
      document.getElementById('fail-log-content').textContent = log || '(No log output available)';
    });
  }
}

// ---------------------------------------------------------------------------
// Event Listeners & Interactive Wiring
// ---------------------------------------------------------------------------

document.addEventListener('DOMContentLoaded', () => {
  // Navigation step buttons in sidebar
  document.querySelectorAll('.nav-step').forEach(btn => {
    btn.addEventListener('click', () => {
      const targetStep = btn.dataset.step;
      const currentIndex = STEP_ORDER.indexOf(state.currentStep);
      const targetIndex = STEP_ORDER.indexOf(targetStep);
      // Allow jumping to already visited steps or next
      if (targetIndex <= currentIndex + 1) {
        setStep(targetStep);
      }
    });
  });
  
  // Explicit next/back buttons
  document.querySelectorAll('[data-nav]').forEach(btn => {
    btn.addEventListener('click', () => {
      setStep(btn.dataset.nav);
    });
  });

  // Welcome page begin button
  document.getElementById('btn-welcome-begin').addEventListener('click', () => {
    setStep('locale');
  });

  // Localization selectors
  document.getElementById('select-keymap').addEventListener('change', e => {
    state.config.kb_layout = e.target.value;
  });
  document.getElementById('select-timezone').addEventListener('change', e => {
    state.config.timezone = e.target.value;
  });
  document.getElementById('select-locale').addEventListener('change', e => {
    state.config.locale = e.target.value;
  });
  
  setupFilterableSelect('search-keymap', 'select-keymap');
  setupFilterableSelect('search-timezone', 'select-timezone');

  // Storage mode tabs
  document.querySelectorAll('.mode-tab').forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.mode-tab').forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      const mode = tab.dataset.mode;
      state.config.storage_mode = mode;
      
      // Toggle mode sections
      ['whole', 'free', 'manual', 'premounted'].forEach(m => {
        const sec = document.getElementById(`mode-sec-${m}`);
        if (sec) sec.classList.toggle('hidden', m !== mode);
      });
      
      triggerPlanUpdate();
    });
  });

  // Free space options
  document.getElementById('input-free-start').addEventListener('input', e => {
    state.config.free_start = Number(e.target.value) || 2048;
    triggerPlanUpdate();
  });
  document.getElementById('input-free-end').addEventListener('input', e => {
    state.config.free_end = Number(e.target.value) || 0;
    triggerPlanUpdate();
  });
  document.querySelectorAll('input[name="esp_mode"]').forEach(r => {
    r.addEventListener('change', e => {
      state.config.esp_mode = e.target.value;
      document.getElementById('free-existing-esp-group').classList.toggle('hidden', e.target.value !== 'existing');
      triggerPlanUpdate();
    });
  });
  document.getElementById('select-free-esp').addEventListener('change', e => {
    state.config.esp_part = e.target.value;
    triggerPlanUpdate();
  });

  // Manual options
  document.getElementById('select-manual-root').addEventListener('change', e => {
    state.config.root_part = e.target.value;
    triggerPlanUpdate();
  });
  document.getElementById('select-manual-esp').addEventListener('change', e => {
    state.config.esp_part = e.target.value;
    triggerPlanUpdate();
  });

  // Premounted options
  document.getElementById('input-premounted-root-path').addEventListener('input', e => {
    state.config.premounted_root = e.target.value.trim();
    triggerPlanUpdate();
  });
  document.getElementById('select-premounted-root').addEventListener('change', e => {
    state.config.root_part = e.target.value;
    triggerPlanUpdate();
  });
  document.getElementById('select-premounted-esp').addEventListener('change', e => {
    state.config.esp_part = e.target.value;
    triggerPlanUpdate();
  });

  // Account controls
  document.querySelectorAll('input[name="user_sudo"]').forEach(r => {
    r.addEventListener('change', e => {
      state.config.user_sudo = e.target.value;
    });
  });
  
  document.getElementById('chk-same-root-pw').addEventListener('change', e => {
    document.getElementById('root-pw-row').classList.toggle('hidden', e.target.checked);
  });
  
  document.getElementById('btn-toggle-pw-vis').addEventListener('click', () => {
    state.passwordsVisible = !state.passwordsVisible;
    const type = state.passwordsVisible ? 'text' : 'password';
    document.getElementById('input-user-pw').type = type;
    document.getElementById('input-user-pw-confirm').type = type;
    document.getElementById('input-root-pw').type = type;
    document.getElementById('input-root-pw-confirm').type = type;
    document.getElementById('pw-vis-text').textContent = state.passwordsVisible ? 'Hide Passwords' : 'Show Passwords';
  });

  // Options controls
  document.querySelectorAll('input[name="mirror_source"]').forEach(r => {
    r.addEventListener('change', e => {
      state.config.mirror_source = e.target.value;
      document.getElementById('mirror-region-group').classList.toggle('hidden', e.target.value !== 'mirrors');
    });
  });
  document.getElementById('input-mirror-region').addEventListener('input', e => {
    state.config.mirror_region = e.target.value.trim();
  });
  document.getElementById('input-extra-packages').addEventListener('input', e => {
    state.config.extra_packages = e.target.value.trim();
  });

  // Summary confirmation checkbox
  document.getElementById('chk-confirm').addEventListener('change', e => {
    state.config.confirmed = e.target.checked;
    document.getElementById('btn-install').disabled = !e.target.checked;
  });

  // Start Install Button
  document.getElementById('btn-install').addEventListener('click', () => {
    startInstallation();
  });

  // Cancel Install Button
  document.getElementById('btn-cancel-install').addEventListener('click', async () => {
    if (confirm('Are you sure you want to cancel the installation process?')) {
      await invokeTauri('cancel_install');
      appendLogLine('[ABORT] User cancelled installation process.', 'stderr');
    }
  });

  // Terminal autoscroll toggle
  const btnScroll = document.getElementById('btn-toggle-autoscroll');
  btnScroll.addEventListener('click', () => {
    state.autoscroll = !state.autoscroll;
    btnScroll.textContent = `Auto-scroll: ${state.autoscroll ? 'ON' : 'OFF'}`;
  });

  // Reboot buttons
  document.getElementById('btn-reboot').addEventListener('click', () => {
    invokeTauri('reboot_system');
  });
  document.getElementById('btn-reboot-failed').addEventListener('click', () => {
    invokeTauri('reboot_system');
  });
  document.getElementById('btn-retry-install').addEventListener('click', () => {
    setStep('summary');
  });

  // Copy fail log button
  document.getElementById('btn-copy-fail-log').addEventListener('click', () => {
    const text = document.getElementById('fail-log-content').textContent;
    navigator.clipboard.writeText(text).then(() => {
      const btn = document.getElementById('btn-copy-fail-log');
      btn.textContent = 'Copied!';
      setTimeout(() => { btn.textContent = 'Copy Log'; }, 2000);
    });
  });

  // Tauri Event Listeners
  if (tauriEvent && typeof tauriEvent.listen === 'function') {
    tauriEvent.listen('install-log', ev => {
      const payload = ev.payload;
      appendLogLine(payload.line, payload.stream);
    });
    
    tauriEvent.listen('install-finished', ev => {
      const payload = ev.payload;
      showInstallFinished(payload.code, payload.success);
    });
  } else {
    // Custom DOM event listeners for standalone mock mode
    document.addEventListener('mock-log', ev => {
      appendLogLine(ev.detail.line, ev.detail.stream);
    });
  }

  // Initial load
  initSystemInfo();
});
