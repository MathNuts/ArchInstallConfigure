#!/bin/bash

dirname=$(dirname "$0")
source ${dirname}/helper.sh

# --------------------------------------------


# Redirect stdout and stderr to log
log_file=installer.log
echo -n "" > ${log_file}
exec 3>&1 1>>${log_file} 2>&1

# EFI only mode
if [[ $1 == "EFIONLY" ]] ; then
    # This is for making a EFI partition for Windows to use
    log "EFI only mode"

    # Select disk
    log "Select disk to install Arch"
    disks=$(lsblk -l -o NAME,TYPE,SIZE | grep disk)
    options "$disks"
    disk=$(chooser "$disks" "Disk")
    log "Using disk: ${G}${disk}${X}"

    pause "Press enter to create empty EFI and format disk"

    (
    echo g      # New GPT partition table

    # EFI
    echo n      # Add a new partition
    echo        # Partition number
    echo        # First sector
    echo +500M  # Last sector
    echo t      # Type
    echo        # Select partition
    echo 1      # EFI type

    echo p      # Print table
    echo w      # Write changes
    ) | sudo fdisk --wipe-partitions=always /dev/$disk

    # Format empty EFI
    log "Formatting EFI"
    mkfs.fat -F32 /dev/${disk}1

    log "EFI partition created on ${disk}"

    exit 0
fi

# Welcome
log "Welcome to the installer"

# Load keyboard
log "Loading keyboard layout"
loadkeys $kb_layout

# Check internet
log "Checking for internet"
while ! ping -c 2 $ping_test ; do
    log "No internet, exitting"
    exit 1
done

# Synchronize time
log "Synchronizing time"
timedatectl set-ntp true

# Temporary mirrorlist
log "Temporary mirrorlist"
mirrors=$(curl -s "https://archlinux.org/mirrorlist/?${mirror_countries}&protocol=https&use_mirror_status=on" | sed -e "s/^#Server/Server/" -e "/^#/d")
echo "$mirrors" > $mirrorlist

# Syncronize pacman
log "Syncronizing pacman"
pacman -Syy

# Rank mirrors
log "Ranking mirrors"
pacman --noconfirm -Syy pacman-contrib
echo "$mirrors" | rankmirrors -n 10 - > $mirrorlist

# Select disk
log "Select disk to install Arch"
disks=$(lsblk -l -o NAME,TYPE,SIZE | grep disk)
options "$disks"
disk=$(chooser "$disks" "Disk")
log "Using disk: ${G}${disk}${X}"

# Dual boot configuration
log "Select Windows dual boot disk"
opts=$(echo -e "No disk\nSame disk\nDifferent disk")
options "$opts"
dual_boot=$(chooser "$opts" "Config")
log "Dual boot config: ${G}${dual_boot} disk${X}"

# Create/Update partition table
log "Creating/Updating partition table"
EFI_partition=${disk}1
boot_partition=${disk}2
root_partition=${disk}3

# Quick fix for nvme drives using p1..pn instead of 1..n
if [[ $disk == *"nvme"* ]] ; then
    EFI_partition=${disk}p1
    boot_partition=${disk}p2
    root_partition=${disk}p3
fi

if [[ $dual_boot == "Same" ]] ; then
    log "Select Windows EFI partition"
    partitions=$(lsblk -l -o NAME,TYPE,SIZE,PARTTYPENAME | awk "/${disk}/ && /part/")
    options "$partitions"
    EFI_partition=$(chooser "$partitions" "Partition")
    log "Using EFI: ${G}${EFI_partition}${X}"

    (
    # Boot
    echo n      # Add a new partition
    echo        # Partition number
    echo        # First sector
    echo +500M  # Last sector

    # Root
    echo n      # Add a new partition
    echo        # Partition number
    echo        # First sector
    echo        # Last sector
    echo t      # Type
    echo        # Select partition
    echo 30     # LVM type

    echo p      # Print table
    echo w      # Write changes
    ) | sudo fdisk --wipe-partitions=always /dev/$disk

    sleep 2

    start_partition=$(lsblk -l -o NAME,TYPE,SIZE,PARTTYPENAME | awk "/${disk}/ && /Linux filesystem/ && /500M/" | tail -n1 | cut -d " " -f1 | tail -c 2)
    boot_partition=${disk}$start_partition
    root_partition=${disk}$((start_partition+1))

    # Quick fix for nvme drives
    if [[ $disk == *"nvme"* ]] ; then
        boot_partition=${disk}p$start_partition
        root_partition=${disk}p$((start_partition+1))
    fi

else
    (
    echo g      # New GPT partition table

    # EFI
    echo n      # Add a new partition
    echo        # Partition number
    echo        # First sector
    echo +500M  # Last sector
    echo t      # Type
    echo        # Select partition
    echo 1      # EFI type

    # Boot
    echo n      # Add a new partition
    echo        # Partition number
    echo        # First sector
    echo +500M  # Last sector

    # Root
    echo n      # Add a new partition
    echo        # Partition number
    echo        # First sector
    echo        # Last sector
    echo t      # Type
    echo        # Select partition
    echo 30     # LVM type

    echo p      # Print table
    echo w      # Write changes
    ) | sudo fdisk --wipe-partitions=always /dev/$disk

    # Format empty EFI
    log "Formatting EFI"
    mkfs.fat -F32 /dev/$EFI_partition
fi

#Format boot
log "Formatting boot"
mkfs.ext4 /dev/$boot_partition

log "EFI at  ${G}${EFI_partition}${X}\nBoot at ${G}${boot_partition}${X}\nRoot at ${G}${root_partition}${X}"

# Setting up encryption
log "Setting up encryption"
# -------------

# Cryptsetup for LVM
password=$(input "Choose encryption password" hidden)
echo "" 1>&3
echo -e "$password" | cryptsetup -q luksFormat /dev/$root_partition
echo -e "$password" | cryptsetup open /dev/$root_partition lvm0
pvcreate /dev/mapper/lvm0
vgcreate volgroup0 /dev/mapper/lvm0
lvcreate -l 100%FREE volgroup0 -n root

# Format root
log "Formatting root"
mkfs.ext4 /dev/volgroup0/root

log "Mounting partitions"
# Mount root
mount /dev/volgroup0/root /mnt

# Make folders
mkdir /mnt/home
mkdir /mnt/boot
mkdir /mnt/etc

# Mount boot
mount /dev/$boot_partition /mnt/boot

# Mount EFI partition
mkdir /mnt/boot/EFI
mount /dev/$EFI_partition /mnt/boot/EFI

# Generate fstab file
log "Generating fstab"
genfstab -U -p /mnt >> /mnt/etc/fstab

# Install base packages
log "Installing base packages"
pacstrap /mnt base

# Switch root to installation and run setup
log "Chroot"
mkdir /mnt/installer
cp -r ${dirname}/. /mnt/installer
rm /mnt/installer/${log_file}
arch-chroot /mnt /bin/bash installer/setup.sh $EFI_partition $boot_partition $root_partition $dual_boot 1>&3 2>&2
rm -rf /mnt/installer

# Backup log to new install
log "Moving install log to user home"
username=$(ls /mnt/home)
user_dir="/mnt/home/${username}"
cp $log_file $user_dir

# Done, umount and poweroff
log "Arch install ${G}complete${X}"
pause "Press <ENTER> to umount and poweroff"
umount -a
poweroff