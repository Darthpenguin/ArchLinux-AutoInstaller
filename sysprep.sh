#!/bin/sh
#Declare Variables
read -p "Enter new hostname: " NEWHOSTNAME
read -p "Enter new username: " NEWUSER
if [ -e /dev/nvme0n1 ]; then
	CRYPTVOL="/dev/nvme0n1p3"
fi
if [ -e /dev/sda ]; then
	CRYPTVOL="/dev/sda3"
fi
#Set timezone
ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc
#Set language
sed -i "/#en_US.UTF-8 UTF-8/ s/# *//" /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 >> /etc/locale.conf
#Set Hostname
echo $NEWHOSTNAME >> /etc/hostname
echo 127.0.0.1 localhost >> /etc/hosts
echo ::1 localhost >> /etc/hosts
echo 127.0.1.1 $NEWHOSTNAME.localdomain myhostname >> /etc/hosts
#Create a crypto_keyfile
mkdir /root/secrets
chmod 700 /root/secrets
head -c 64 /dev/urandom > /root/secrets/crypto_keyfile.bin
chmod 600 /root/secrets/crypto_keyfile.bin
cryptsetup -v luksAddKey -i 1 $CRYPTVOL /root/secrets/crypto_keyfile.bin
#Configure mkinitcpio
sed -i "/^HOOKS=.*/c\HOOKS=(base udev autodetect keyboard modconf block encrypt lvm2 filesystems resume fsck)" /etc/mkinitcpio.conf
sed -i "/^FILES=()/c\FILES=(\/root\/secrets\/crypto_keyfile.bin)" /etc/mkinitcpio.conf
mkinitcpio -p linux
#Create root password
passwd
#Configure GRUB
sed -i "/#GRUB_ENABLE_CRYPTODISK=y/ s/# *//" /etc/default/grub
IFS=\" read -r _ vUUID _ < <(blkid $CRYPTVOL -s UUID)
sed -i "/^GRUB_CMDLINE_LINUX=.*/c\GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${vUUID}:cryptlvm\" root=\/dev\/vg\/root cryptkey=rootfs:\/root\/secrets\/crypto_keyfile.bin resume=\/dev\/vg\/swap" /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/efi
grub-mkconfig -o /boot/grub/grub.cfg
chmod 700 /boot
#Create new user
useradd -m -G wheel,rfkill -s /bin/bash $NEWUSER
echo "Enter Password for $NEWUSER"
passwd $NEWUSER
#Configure nano
sed -i "/# include \"/usr/share/nano/*.nanorc\"/ s/# *//" /etc/nanorc
#Configure sudo
sed -i "/# %wheel ALL=(ALL) ALL/ s/# *//" /etc/sudoers
sed -i '/^# Defaults!REBOOT !log_output/a Defaults env_reset,pwfeedback' /etc/sudoers
#Configure pacage manager
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
curl -s "https://archlinux.org/mirrorlist/?country=CA&country=GB&country=US&protocol=https&ip_version=4&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 6 - > /etc/pacman.d/mirrorlist
#Install more packages
lspci -v | egrep -i --color 'vga|3d|2d' | grep "Intel Corporation HD Graphics" &> /dev/null
if [ $? == 0 ]; then
	VIDDRIVER=xf86-video-intel
fi
lspci -v | egrep -i --color 'vga|3D|2d' | grep "AMD" &> /dev/null
if [ $? == 0 ]; then
	VIDDRIVER=xf86-video-amdgpu
fi
pacman -Syy
pacman -S $VIDDRIVER cups man xorg-server xorg-twm xorg-xclock xterm xcursor-vanilla-dmz xf86-input-libinput xorg-xinit cinnamon arc-gtk-theme xed xreader lightdm lightdm-gtk-greeter xdg-user-dirs xdg-user-dirs-gtk cheese simple-scan file-roller gnome-calculator gnome-disk-utility yelp yelp-tools gnome-screenshot gnome-sound-recorder gnome-terminal gnome-logs meson networkmanager
systemctl enable NetworkManager
systemctl enable lightdm
systemctl enable cups
systemctl enable avahi-daemon
#Configure lightdm
sed -i "/^#greeter-session=example-gtk-gnome/c\greeter-session=lightdm-gtk-greeter" /etc/lightdm/lightdm.conf
