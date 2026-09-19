# Omarchy Secure Boot Setup

Provision Secure Boot keys on an existing Omarchy 4.0.4 installation using
Limine 12.x, UKI boot artifacts, and `sbctl`.

## Requirements

- Omarchy 4.0.4 with Limine 12.x and UKI boot enabled
- A UEFI boot, with Secure Boot disabled
- Firmware in Setup Mode
- Physical or console access to firmware setup for recovery if needed

The script expects Omarchy's Limine configuration at:

- `/etc/limine-entry-tool.conf`
- `/etc/limine-entry-tool.d/omarchy-uki.conf`

It verifies that `ENABLE_VERIFICATION=yes` and `ENABLE_UKI=yes` are enabled
before changing firmware keys.

## Usage

Clone the repository on the Omarchy installation, inspect the script, then run:

```bash
sudo ./setup-secureboot.sh
```

The script installs `sbctl`, creates keys if necessary, enrolls them while
retaining Microsoft's certificates, rebuilds the Limine boot artifacts, and
verifies the Limine EFI binary and Omarchy UKI. It reboots into firmware setup
only after both signature checks succeed.

## Important

Key enrollment changes the firmware Secure Boot key database. Confirm that the
machine is in Setup Mode and keep a recovery path available before running the
script. Do not interrupt it during key enrollment or boot-artifact generation.

The script currently targets these generated files:

```text
/boot/EFI/limine/limine_x64.efi
/boot/EFI/Linux/omarchy_linux.efi
```

After the reboot, enable Secure Boot in firmware setup and boot the installed
Omarchy system. Verify the final state with:

```bash
sbctl status
```
