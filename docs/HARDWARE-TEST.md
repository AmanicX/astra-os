# Real-Hardware Test Checklist

Status: **not verified.** Everything in this file must be run by the owner on
real hardware. A VM cannot prove these paths.

## NVIDIA

- [ ] Current branch: an RTX card (Turing or newer) boots to SDDM, niri and
      Noctalia with `nvidia-open`, `nvidia_drm.modeset=1`,
      `nvidia_drm.fbdev=1`, NVreg_PreserveVideoMemoryAllocations=1.
- [ ] GTX 16xx (Turing) uses the current branch, not 580xx.
- [ ] GTX 10xx (Pascal) uses the 580xx branch.
- [ ] Maxwell and Volta use the 580xx branch.
- [ ] Pre-Maxwell falls back to nouveau with a clear installer message.
- [ ] Hybrid Intel+NVIDIA and AMD+NVIDIA use `prime-run` without forcing the
      dGPU as primary.
- [ ] Suspend, hibernate and resume with the proprietary driver.
- [ ] External monitor hotplug and multi-monitor layout.
- [ ] Wayland sessions: no black screen after sleep; niri's documented NVIDIA
      workaround is applied.

## Graphics and display

- [ ] AMD Vega and RDNA systems: VA-API hardware decode works in mpv.
- [ ] Intel systems: `vainfo` shows the expected driver; media playback works.
- [ ] Basic-graphics boot entry works on hardware that fails the default entry.
- [ ] Laptop backlight keys work through Noctalia.
- [ ] Fractional scaling and mixed-DPI monitors behave.

## Laptop hardware

- [ ] Wi-Fi connects from the Noctalia network panel.
- [ ] Bluetooth pairs a device from the Noctalia panel.
- [ ] Battery, AC and power profiles show correct values.
- [ ] Suspend/resume and lid behavior.
- [ ] Audio output, microphone and headset hotplug with SOF firmware.
- [ ] Webcam and card reader (if present).

## Firmware and boot

- [ ] UEFI boot with Secure Boot disabled.
- [ ] Secure Boot enabled behavior is clearly explained (v1 target is
      unsigned; the installer must not brick boot).
- [ ] GRUB menu shows snapshots and detects Windows in dual-boot mode.
- [ ] Plymouth handoff from GRUB is smooth.
- [ ] BIOS/legacy boot exits the installer with a clear message.

## Desktop and apps

- [ ] SDDM renders the chosen theme offline and logs into niri.
- [ ] Noctalia panels (network, Bluetooth, audio, battery, clipboard, lock)
      work without network.
- [ ] The keybind overlay opens with the documented shortcut.
- [ ] Neovim starts with no errors and no network calls.
- [ ] zsh prompt renders the `1_shell` theme.
- [ ] Nautilus mounts Android/SMB devices.
- [ ] Printing works.
- [ ] The full installed-system boot test has an empty `systemctl --failed`
      and a clean `pacman -Qk`.

## Updater

- [ ] `astra-update --check` reaches the stable channel and reports the diff.
- [ ] An update applies, creates a snapshot and recommends a reboot when
      needed.
- [ ] Rollback works from the GUI and from GRUB.
- [ ] Battery/AC, pacman lock, network and game-running guards behave.
