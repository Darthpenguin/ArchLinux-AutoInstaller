#!/bin/sh
#Turn on Network Time Protocol
timedatectl set-ntp true
#Get device name
function listdisks {
	disk=()
	size=()
	name=()
	while IFS= read -r -d $'\0' device; do
		device=${device/\/dev\//}
		disk+=($device)
		name+=("`cat "/sys/class/block/$device/device/model"`")
		size+=("`cat "/sys/class/block/$device/size"`")
	done < <(find "/dev/" -regex '/dev/sd[a-z]\|/dev/vd[a-z]\|/dev/hd[a-z]\|/dev/nvme[0-9]n[0-9]' -print0)
	echo -e "Device Name\tModel\t\t\tSize"
	for i in `seq 0 $((${#disk[@]}-1))`; do
		echo -e "${disk[$i]}\t\t${name[$i]}\t${size[$i]}"
	done
}
function gettarget {
	echo
	echo "Enter the name of the target device you want to install Arch Linux on."
	echo "!!!WARNING!!! THIN WILL DESTROY ALL THE DATA ON THE DISK!"
	read -p "Device: " DISK
	TARGET="/dev/$DISK"
	echo $TARGET
	if [ ! -e $TARGET ]; then
		echo "Target does not exist. Try again or press [Ctrl]+[C] to terminate"
		gettarget
	fi
}
#Wipe /dev/sda and partition
function partitiondisk {
	echo "Partitioning the disk..."
	sgdisk --zap-all "$TARGET"
	sgdisk -n 0:0:+1MiB -t 0:ef02 -c 0:grub "$TARGET"
	sgdisk -n 0:0:+512MiB -t 0:ef00 -c 0:boot "$TARGET"
	sgdisk -n 0:0:0 -t 0:8309 -c 0:cryptlvm "$TARGET"
	echo
}
function setefivar {
	fdisk -l "$TARGET"
	echo "Enter the device name for the efi partition (partition 2)"
	read -p "EFI Partition: " EFIPART
	if [ ! -e "$EFIPART" ]; then
		echo "That partiton does not exist. Try again or press [Ctrl]+[C] to terminate"
		setefivar
	fi
}
function setcryptvar {
	fdisk -l $TARGET
	echo "Enter th device name for the large volume you want to encrypt (partition 3)"
	read -p "LUKS Partition: " CRYPTPART
	if [[ ! -e "$CRYPTPART" ]]; then
		echo "That partiton does not exist. Tray again or press [Ctrl]+[C] to terminate"
		setcryptvar
	fi
}
function encryptdisk {
#Encrypt partition 3
	cryptsetup luksFormat --type luks1 --use-random -S 1 -s 512 -h sha512 -i 5000 $CRYPTPART
	cryptsetup open $CRYPTPART cryptlvm
}
#Create logical volumes
function createlvm {
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
	mkfs.fat -F32 $EFIPART
	mkdir /mnt/efi
	mount $EFIPART /mnt/efi
}
function installbasesys {
	echo "Do you have an Intel or an AMD processor?"
	read -p "Processor: " VENDOR
	if [ "$VENDOR"=="Intel" ]; then
		PROCESSOR="intel-ucode"
	elif [ "$VENDOR"=="AMD" ]; then
		PROCESSOR="amd-ucode"
	else
		echo "Invalid entry."
		installbasesys
	fi
	pacstrap /mnt base linux linux-firmware mkinitcpio lvm2 vi vim nano dhcpcd wpa_supplicant grub efibootmgr $PROCESSOR sudo pacman-contrib base-devel dmidecode
	genfstab -U /mnt >> /mnt/etc/fstab
}
listdisks
gettarget
partitiondisk
setefivar
setcryptvar
encryptdisk
createlvm
installbasesys
cp sysprep.sh /mnt/root/sysprep.sh
mkdir -p /mnt/etc/skel/.local/share/xed/styles
cp xed-arc-color-theme.xml /mnt/etc/skel/.local/share/xed/styles/xed-arc-color-theme.xml
cp bash.bashrc /mnt/etc/bash.bashrc
cp bash.bashrc /mnt/etc/skel/.bashrc
arch-chroot /mnt ./root/sysprep.sh
