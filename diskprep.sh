#!/bin/sh
timedatectl set-ntp true
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
	echo "Installing system to $TARGET"
	if [ ! -e $TARGET ]; then
		echo "Target does not exist. Try again or press [Ctrl]+[C] to terminate"
		gettarget
	fi
}
function partitiondisk {
	echo "Partitioning the disk..."
	sgdisk --zap-all "$TARGET"
	sgdisk -n 0:0:+1MiB -t 0:ef02 -c 0:grub "$TARGET"
	sgdisk -n 0:0:+512MiB -t 0:ef00 -c 0:boot "$TARGET"
	sgdisk -n 0:0:0 -t 0:8309 -c 0:cryptlvm "$TARGET"
}
function setefivar {
    if [[ ${TARGET} =~ /dev/sd[a-z] || /dev/vd[a-z] || /dev/hd[a-z] ]]; then
        EFIPART=${TARGET}2
    elif [[ ${TARGET} =~ /dev/nvme[0-9]n[0-9] ]]; then
        EFIPART=${TARGET}p2
    fi
}
function setcryptvar {
	if [[ ${TARGET} =~ /dev/sd[a-z] || /dev/vd[a-z] || /dev/hd[a-z] ]]; then
        EFIPART=${TARGET}3
    elif [[ ${TARGET} =~ /dev/nvme[0-9]n[0-9] ]]; then
        EFIPART=${TARGET}p3
    fi
}
function encryptdisk {
	cryptsetup luksFormat --type luks1 --use-random -S 1 -s 512 -h sha512 -i 5000 $CRYPTPART
	cryptsetup open $CRYPTPART cryptlvm
}
function createlvm {
	pvcreate /dev/mapper/cryptlvm
	vgcreate vg /dev/mapper/cryptlvm
	lvcreate -L 16G vg -n swap
	lvcreate -L 32G vg -n root
	lvcreate -l 100%FREE vg -n home
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
    lscpu | grep -i intel > /dev/null
    if [[ $? = 0 ]]; then
        MICROCODE=intel-ucode
    fi
    lscpu | grep -i amd > /dev/null
    if [[ $? = 0 ]]; then
        MICROCODE=amd-ucode
    fi
    if [[ -z $MICROCODE ]]; then
        echo
        echo "PROCESSOR TYPE UNKNOWN! NOT INSTALLING MICROCODE!"
    fi
	pacstrap /mnt base linux linux-firmware mkinitcpio $MICROCODE lvm2 vi nano dhcpcd wpa_supplicant grub efibootmgr sudo pacman-contrib dmidecode
	genfstab -U /mnt >> /mnt/etc/fstab
}
clear
echo "Welcome to the Arch Linux AutoInstaller for laptops."
listdisks
gettarget
partitiondisk
setefivar
setcryptvar
encryptdisk
createlvm
installbasesys
chmod +x sysprep.sh
cp sysprep.sh /mnt/root/sysprep.sh
cp aurconfig.sh /mnt/root/aurconfig.sh
mkdir -p /mnt/etc/skel/.local/share/xed/styles
cp xed-arc-color-theme.xml /mnt/etc/skel/.local/share/xed/styles/xed-arc-color-theme.xml
cp bash.bashrc /mnt/etc/bash.bashrc
cp bash.bashrc /mnt/etc/skel/.bashrc
arch-chroot /mnt /root/sysprep.sh