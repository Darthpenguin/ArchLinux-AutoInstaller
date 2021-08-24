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
	echo "!!!WARNING!!! THIS WILL DESTROY ALL THE DATA ON THE DISK!"
	read -p "Device: " DISK
	TARGET="/dev/$DISK"
	if [ ! -e $TARGET ]; then
		echo "Target does not exist. Try again or press [Ctrl]+[C] to terminate"
		gettarget
	fi
	echo "Installing system to $TARGET"
}
function partitiondisk {
	echo "Partitioning the disk..."
	sgdisk --zap-all "$TARGET"
	sgdisk -n 0:0:+1MiB -t 0:ef02 -c 0:grub "$TARGET"
	sgdisk -n 0:0:+512MiB -t 0:ef00 -c 0:boot "$TARGET"
	sgdisk -n 0:0:0 -t 0:8309 -c 0:cryptlvm "$TARGET"
}
function setpartvars {
    if [[ ${TARGET} =~ /dev/sd[a-z] || /dev/vd[a-z] || /dev/hd[a-z] ]]; then
        EFIPART=${TARGET}2
	CRYPTPART=${TARGET}3
    fi
    if [[ ${TARGET} =~ /dev/nvme[0-9]n[0-9] ]]; then
        EFIPART=${TARGET}p2
	CRYPTPART=${TARGET}p3
    fi
    echo "EFI partition is $EFIPART"
    echo "LUKS partition is $CRYPTPART"
}
function encryptdisk {
	echo "Encrypting $CRYPTPART"
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
echo
echo -e '\033[1mWelcome to the Arch Linux AutoInstaller for laptops\033[0m'
echo
echo "This installer will create a small bios and gpt partition on the disk you specify"
echo "This installer will prepare the rest of the disk for encryption"
echo -e 'A \033[1m16 GiB\033[0m logical volume will be configured for SWAP.'
echo "Edit the script to change the size of the swap partition before executing the script."
echo -e 'The logical volume for the base Arch system will be set for \033[1m32 GiB\033[0m unless you have edited this script.'
echo -e '\033[1mBe sure you are connected to the internet before running this script.\033[0m'
echo "After partitioning, encrypting, lvm creation, formatting and volume mounting the base system and key packages will be installed."
echo "We will automatically chroot into the new Arch system and complete basic system configuration and install additional packages."
echo -e 'This script assumes your timezone is \033[1mEST\033[0m and sets your location as \033[1mToronto Canada.\033[0m'
echo -e 'The default language will be set to \033[1mEnglish US.\033[0m'
echo 'The pacman mirrorlist will be auto generate based on the the fastest mirrors in US, Canada, and UK'
echo 'The default desktop environment will be cinnamon.'
echo
read -p "Do you want to continue? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 
fi
echo
listdisks
gettarget
partitiondisk
setpartvars
encryptdisk
createlvm
installbasesys
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
mount --bind $SCRIPTPATH /mnt/mnt
chmod +x $SCRIPTPATH/sysprep.sh
arch-chroot /mnt /mnt/sysprep.sh
