#!/bin/sh
#Get device name
if [ -e /dev/nvme0n1 ]; then
	TARGET=/dev/nvme0n1
	EFIVOL=/dev/nvme0n1p2
	CRYPTVOL=/dev/nvme0n1p3
fi
if [ -e /dev/sda ]; then
	TARGET=/dev/sda
	EFIVOL=/dev/sda2
	CRYPTVOL=/dev/sda3
fi
#Turn on Network Time Protocol
timedatectl set-ntp true
#Wipe /dev/sda and partition
sgdisk --zap-all $TARGET
sgdisk -n 0:0:+1MiB -t 0:ef02 -c 0:grub $TARGET
sgdisk -n 0:0:+512MiB -t 0:ef00 -c 0:boot $TARGET
sgdisk -n 0:0:0 -t 0:8309 -c 0:cryptlvm $TARGET
#Encrypt partition 3
cryptsetup luksFormat --type luks1 --use-random -S 1 -s 512 -h sha512 -i 5000 $CRYPTVOL
cryptsetup open $CRYPTVOL cryptlvm
#Create logical volumes
pvcreate /dev/mapper/cryptlvm
vgcreate vg /dev/mapper/cryptlvm
lvcreate -L 16G vg -n swap
lvcreate -L 32G vg -n root
lvcreate -l 100%FREE vg -n home
#Format and mount the partitions
mkfs.ext4 /dev/vg/root
mkfs.ext4 /dev/vg/home
mkswap /dev/vg/swap
mount /dev/vg/root /mnt
mkdir /mnt/home
mount /dev/vg/home /mnt/home
swapon /dev/vg/swap
mkfs.fat -F32 $EFIVOL
mkdir /mnt/efi
mount $EFIVOL /mnt/efi
#Install the base system
pacstrap /mnt base linux linux-firmware mkinitcpio lvm2 vi nano dhcpcd wpa_supplicant grub efibootmgr intel-ucode sudo pacman-contrib
#Create the fstab
genfstab -U /mnt >> /mnt/etc/fstab
echo "Copy files to /mnt/root/ then type arch-chroot /mnt to enter the new Arch Installation."
