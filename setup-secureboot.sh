#!/usr/bin/env bash

set -euo pipefail

# Omarchy Secure Boot setup
#
# Target:
#   - Omarchy 4.0.4
#   - Limine 12.x
#   - UKI boot
#   - sbctl-managed Secure Boot keys
#
# Limine and mkinitcpio handle signing automatically once sbctl is installed.
# This script provisions the keys, rebuilds the boot artifacts, verifies
# the resulting signatures, and then reboots into UEFI firmware setup.

# Run as root.
if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

echo "==> Checking UEFI mode..."

if [[ ! -d /sys/firmware/efi ]]; then
    echo "ERROR: System is not booted in UEFI mode."
    exit 1
fi

echo "==> Installing sbctl..."

pacman -S --needed --noconfirm sbctl

echo "==> Checking Secure Boot state..."

status="$(sbctl status)"

if ! grep -qiE 'Setup Mode:.*Enabled' <<< "$status"; then
    echo "ERROR: Firmware is not in Setup Mode."
    echo
    echo "$status"
    exit 1
fi

if ! grep -qiE 'Secure Boot:.*Disabled' <<< "$status"; then
    echo "ERROR: Secure Boot is not disabled."
    echo
    echo "$status"
    exit 1
fi

echo "    Setup Mode: enabled"
echo "    Secure Boot: disabled"

echo "==> Checking Limine configuration..."

if [[ ! -f /etc/limine-entry-tool.conf ]]; then
    echo "ERROR: /etc/limine-entry-tool.conf not found."
    exit 1
fi

if ! grep -qE '^ENABLE_VERIFICATION=yes$' \
    /etc/limine-entry-tool.conf; then
    echo "ERROR: ENABLE_VERIFICATION=yes is not configured."
    exit 1
fi

if ! grep -qE '^ENABLE_UKI=yes$' \
    /etc/limine-entry-tool.d/omarchy-uki.conf; then
    echo "ERROR: ENABLE_UKI=yes is not configured."
    exit 1
fi

echo "    Limine verification: enabled"
echo "    UKI: enabled"

echo "==> Creating Secure Boot keys..."

if [[ ! -f /var/lib/sbctl/keys/PK/PK.key ]]; then
    sbctl create-keys
else
    echo "    Keys already exist; keeping them."
fi

echo "==> Enrolling Secure Boot keys..."

sbctl enroll-keys --microsoft

echo "==> Rebuilding Limine boot artifacts..."

limine-mkinitcpio

LIMINE="/boot/EFI/limine/limine_x64.efi"
UKI="/boot/EFI/Linux/omarchy_linux.efi"

if [[ ! -f "$LIMINE" ]]; then
    echo "ERROR: Limine EFI binary was not generated."
    exit 1
fi

if [[ ! -f "$UKI" ]]; then
    echo "ERROR: Omarchy UKI was not generated."
    exit 1
fi

echo "==> Verifying signed boot artifacts..."

if ! sbctl verify "$LIMINE"; then
    echo
    echo "ERROR: Limine EFI signature verification failed."
    echo "The system will NOT reboot into firmware setup."
    exit 1
fi

if ! sbctl verify "$UKI"; then
    echo
    echo "ERROR: Omarchy UKI signature verification failed."
    echo "The system will NOT reboot into firmware setup."
    exit 1
fi

echo
echo "Secure Boot provisioning completed successfully."
echo
echo "Verified:"
echo "  $LIMINE"
echo "  $UKI"
echo
echo "Rebooting into UEFI firmware setup..."
sleep 2

systemctl reboot --firmware-setup
