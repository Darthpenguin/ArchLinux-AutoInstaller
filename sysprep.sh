#!/bin/sh
#Declare Variables
dmidecode | grep -A3 '^System Information'
read -p "Enter new hostname: " NEWHOSTNAME
read -p "Enter new username: " NEWUSER
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
	echo "Enter the name of the primary system disk"
	echo -p "Disk: " DISK
	if [ ! -z $DISK ]; then
		TARGET="/dev/$DISK"
	else
		echo "Please do not leave this blank."
		gettarget
	fi
	echo $TARGET
	if [ ! -e "$TARGET" ]; then
		echo "That disk does not exist. Try again or press [Ctrl]+[C] to terminate"
		gettarget
	fi
}
function setcryptvar {
	fdisk -l $TARGET
	echo "Enter the device name for the large volume you want to encrypt (partition 3)"
	read -p "LUKS Partition: " CRYPTPART
	if [ ! -e "$CRYPTPART" ]; then
		echo "That partiton does not exist. Tray again or press [Ctrl]+[C] to terminate"
		setcryptvar
	fi
}
listdisks
gettarget
setcryptvar
echo "Setting the timezone..."
ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
echo "Configuring hardware clock..."
hwclock --systohc
echo "Settting language..."
sed -i "/#en_US.UTF-8 UTF-8/ s/# *//" /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 >> /etc/locale.conf
echo "Setting hostname..."
echo $NEWHOSTNAME >> /etc/hostname
echo 127.0.0.1 localhost >> /etc/hosts
echo ::1 localhost >> /etc/hosts
echo 127.0.1.1 $NEWHOSTNAME.localdomain myhostname >> /etc/hosts
echo "Creating crypto_keyfile..."
mkdir /root/secrets
chmod 700 /root/secrets
head -c 64 /dev/urandom > /root/secrets/crypto_keyfile.bin
chmod 600 /root/secrets/crypto_keyfile.bin
cryptsetup -v luksAddKey -i 1 $CRYPTPART /root/secrets/crypto_keyfile.bin
echo "Configuring mkinitcpio..."
sed -i "/^HOOKS=.*/c\HOOKS=(base udev autodetect keyboard modconf block encrypt lvm2 filesystems resume fsck)" /etc/mkinitcpio.conf
sed -i "/^FILES=()/c\FILES=(\/root\/secrets\/crypto_keyfile.bin)" /etc/mkinitcpio.conf
mkinitcpio -p linux
echo "Create a password for root user."
passwd
echo "Configuring GRUB..."
sed -i "/#GRUB_ENABLE_CRYPTODISK=y/ s/# *//" /etc/default/grub
IFS=\" read -r _ vUUID _ < <(blkid $CRYPTPART -s UUID)
sed -i "/^GRUB_CMDLINE_LINUX=.*/c\GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${vUUID}:cryptlvm\" root=\/dev\/vg\/root cryptkey=rootfs:\/root\/secrets\/crypto_keyfile.bin resume=\/dev\/vg\/swap" /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/efi
grub-mkconfig -o /boot/grub/grub.cfg
chmod 700 /boot
echo "Creating new user..."
useradd -m -G wheel,rfkill -s /bin/bash $NEWUSER
echo "Enter Password for $NEWUSER"
passwd $NEWUSER
echo "Configuring nano..."
sed -i "/# include \"/usr/share/nano/*.nanorc\"/ s/# *//" /etc/nanorc
echo "Configuring sudo..."
sed -i "/# %wheel ALL=(ALL) ALL/ s/# *//" /etc/sudoers
sed -i '/^# Defaults!REBOOT !log_output/a Defaults env_reset,pwfeedback' /etc/sudoers
echo "Configure package manager..."
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
curl -s "https://archlinux.org/mirrorlist/?country=CA&country=GB&country=US&protocol=https&ip_version=4&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 6 - > /etc/pacman.d/mirrorlist
echo "Installing packages..."
pacman -Syy
lspci -v | egrep -i --color 'vga|3d|2d' | grep "Intel Corporation HD Graphics" &> /dev/null
if [ $? == 0 ]; then
	pacman -S xf86-video-intel
fi
lspci -v | egrep -i --color 'vga|3D|2d' | grep "AMD" &> /dev/null
if [ $? == 0 ]; then
	pscman -S xf86-video-amdgpu
elif [ $? == 1 ]; then
	pacman -Ss xf86-video
	echo "What video driver do you want to install?"
	read -p "Video driver: " VIDDRIVER
	if [ -z "$VIDDRIVER" ]; then
		echo "No video driver selected. Proceeding."
	else
		pacman -S $VIDDRIVER
	fi
fi
pacman -S cups man xorg-server xorg-twm xorg-xclock xterm xcursor-vanilla-dmz xf86-input-libinput xorg-xinit cinnamon arc-gtk-theme xed xreader lightdm lightdm-gtk-greeter xdg-user-dirs xdg-user-dirs-gtk cheese simple-scan file-roller gnome-calculator gnome-disk-utility yelp yelp-tools gnome-screenshot gnome-sound-recorder gnome-terminal gnome-logs meson networkmanager
systemctl enable NetworkManager
systemctl enable lightdm
systemctl enable cups
systemctl enable avahi-daemon
echo "Configuring lightdm..."
sed -i "/^#greeter-session=example-gtk-gnome/c\greeter-session=lightdm-gtk-greeter" /etc/lightdm/lightdm.conf
echo
echo "Install complete. exit. reboot. and pray."
