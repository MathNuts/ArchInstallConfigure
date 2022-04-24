#!/bin/bash

dirname=$(dirname "$0")
source ${dirname}/helper.sh

# --------------------------------------------

# Redirect stdout and stderr
exec 3>&1 1>&2

# Set variables
EFI_partition=$1
boot_partition=$1
root_partition=$3
dual_boot=$4

# Determine CPU vendor
if [[ $(grep vendor_id /proc/cpuinfo | grep GenuineIntel) ]] ; then
    log "CPU vendor: Intel"
    ucode=intel-ucode
elif  [[ $(grep vendor_id /proc/cpuinfo | grep AuthenticAMD) ]] ; then
    ucode=amd-ucode
    log "CPU vendor: AMD"
else
    log "Could not determine CPU vendor, exitting"
    exit 1
fi

# Install packages
log "Installing necessary packages"
pacman --noconfirm -S linux-zen linux-zen-headers linux-firmware nano base-devel networkmanager dialog lvm2 grub efibootmgr dosfstools os-prober mtools ntp git $ucode

# Enable networkmanager
log "Enabling NetworkManager"
systemctl enable NetworkManager

# Set locale
log "Generate and set locales"
sed -i -e 's/^#en_US\.UTF-8/en_US\.UTF-8/' /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf

# Allow sudo
log "Setup sudo"
sed -i -e 's/^# %wheel ALL=(ALL) NOPASSWD/%wheel ALL=(ALL) NOPASSWD/' /etc/sudoers

# Setup mkinitcpio
log "Generate mkinitcpio"
sed -i -e 's/block filesystems/block encrypt lvm2 filesystems/g' /etc/mkinitcpio.conf
mkinitcpio -p linux-zen

# Setup GRUB
log "Installing GRUB"
sed -i -e "s|loglevel=3 quiet|loglevel=3 cryptdevice=/dev/$root_partition:volgroup0:allow-discards quiet|g" /etc/default/grub
sed -i -e 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/g' /etc/default/grub
grub-install --target=x86_64-efi --bootloader-id=GRUB
if [[ $dual_boot == "Different" ]] ; then
    pacman --noconfirm -S ntfs-3g
    log "Select Windows EFI partition"
    partitions=$(lsblk -l -o NAME,TYPE,SIZE,PARTTYPENAME | awk "/part/")
    options "$partitions"
    WIN_partition=$(chooser "$partitions" "Partition")
    log "Windows EFI: $G$WIN_partition$X"
    mkdir windows
    mount /dev/$WIN_partition windows

    os-prober
    grub-mkconfig -o /boot/grub/grub.cfg

    umount windows
    rmdir windows
else
    os-prober
    grub-mkconfig -o /boot/grub/grub.cfg
fi

# Set timezone and time
log "Setting time"
ln -sf /usr/share/zoneinfo/Europe/Oslo /etc/localtime
ntpd -qg
hwclock --systohc

# Set keyboard layout
log "Change keyboard layout"
echo "KEYMAP=${kb_layout}" > /etc/vconsole.conf

log "User management"
username=$(input "Enter username" shown)
password=$(input "Enter root/${username} password" hidden)
echo "" 1>&3

# Set password for root
echo -e "$password\n$password" | passwd

# Make user
useradd -m -g users -G wheel $username

# Set pass for user
echo -e "$password\n$password" | passwd $username

# Copy files to user home
new_dir="/home/${username}/installer"
mkdir $new_dir
cp -r ${dirname}/. $new_dir
chown -R ${username}:users $new_dir