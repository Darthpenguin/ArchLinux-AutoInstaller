#!/bin/sh
########################################################
### Getting name of the partition which contains...  ###
### a crypto_LUKS file system.                       ###
### The resulting variable should probably be...     ###
### /dev/nvme0n1p3 or /dev/sda3...                   ###
### ...depenting on the drive type                   ###
###                                                  ###
### There should only be one encrypted partition.    ###
### If you have more than one encrypted partition... ###
### ...this whole thing might just go tits up        ###
########################################################
CRYPTPART=$(lsblk -fs | grep crypto_LUKS | cut -f3 -d' ' | head -n 1)
CRYPTPART="/dev/${CRYPTPART:2}"
###########################################################
### Setting the timezone, clock, location, and language ###
###########################################################
echo "Setting the timezone..."
ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
echo "Configuring hardware clock..."
hwclock --systohc
echo "Settting language..."
sed -i "/#en_US.UTF-8 UTF-8/ s/# *//" /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 >> /etc/locale.conf
###########################################
### Configuring hostname and hosts file ###
###########################################
dmidecode | grep -A3 '^System Information'
read -p "Enter new hostname: " NEWHOSTNAME
echo "Setting hostname..."
echo $NEWHOSTNAME >> /etc/hostname
echo 127.0.0.1 localhost >> /etc/hosts
echo ::1 localhost >> /etc/hosts
echo 127.0.1.1 $NEWHOSTNAME.localdomain myhostname >> /etc/hosts
##################################
### Configuring crypto_keyfile ###
##################################
echo "Creating crypto_keyfile..."
mkdir /root/secrets
chmod 700 /root/secrets
head -c 64 /dev/urandom > /root/secrets/crypto_keyfile.bin
chmod 600 /root/secrets/crypto_keyfile.bin
cryptsetup -v luksAddKey -i 1 $CRYPTPART /root/secrets/crypto_keyfile.bin
##############################
### Configuring mkinitcpio ###
##############################
echo "Configuring mkinitcpio..."
sed -i "/^HOOKS=.*/c\HOOKS=(base udev autodetect keyboard modconf block encrypt lvm2 filesystems resume fsck)" /etc/mkinitcpio.conf
sed -i "/^FILES=()/c\FILES=(\/root\/secrets\/crypto_keyfile.bin)" /etc/mkinitcpio.conf
mkinitcpio -p linux
#############################
### Configuring root user ###
#############################
echo "Create a password for root user."
passwd
########################
### Configuring GRUB ###
########################
echo "Configuring GRUB..."
sed -i "/#GRUB_ENABLE_CRYPTODISK=y/ s/# *//" /etc/default/grub
IFS=\" read -r _ vUUID _ < <(blkid $CRYPTPART -s UUID)
sed -i "/^GRUB_CMDLINE_LINUX=.*/c\GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${vUUID}:cryptlvm root=\/dev\/vg\/root cryptkey=rootfs:\/root\/secrets\/crypto_keyfile.bin resume=\/dev\/mapper\/vg-swap\"" /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/efi
grub-mkconfig -o /boot/grub/grub.cfg
chmod 700 /boot
##########################
### Creating new user ####
##########################
read -p "Enter new username: " NEWUSER
echo "Creating new user..."
useradd -m -G wheel,rfkill -s /bin/bash $NEWUSER
echo "Enter Password for $NEWUSER"
passwd $NEWUSER
mkdir /home/$NEWUSER/Desktop
chown $NEWUSER /home/$NEWUSER/Desktop
chgrp $NEWUSER /home/$NEWUSER/Desktop
cp /mnt/Comtrya.sh /home/$NEWUSER/Desktop/Comtrya.sh
chown $NEWUSER /home/$NEWUSER/Desktop/Comtrya.sh
chgrp $NEWUSER /home/$NEWUSER/Desktop/Comtrya.sh
chmod +x /home/$NEWUSER/Desktop/Comtrya.sh
###################################
### Editing global config files ###
###################################
echo EDITOR=nano >> /etc/environment
echo VISUAL=/usr/bin/xed >> /etc/environment
echo "Configuring nano..."
sed -i "/# include \"\/usr\/share\/nano\/*.nanorc\"/ s/# *//" /etc/nanorc
echo "Configuring sudo..."
sed -i "/# %wheel ALL=(ALL) ALL/ s/# *//" /etc/sudoers
sed -i '/^# Defaults!REBOOT !log_output/a Defaults env_reset,pwfeedback' /etc/sudoers
echo "Configure package manager..."
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
curl -s "https://archlinux.org/mirrorlist/?country=CA&country=GB&country=US&protocol=https&ip_version=4&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 6 - > /etc/pacman.d/mirrorlist
###########################
### Installing packages ###
###########################
echo "Installing packages..."
pacman --noconfirm -Syy
pacman --noconfirm -S man xdg-user-dirs meson bash-completion ttf-dejavu base-devel
pacman --noconfirm -S xorg xorg-drivers xorg-twm xorg-xclock xterm xcursor-vanilla-dmz xorg-xinit
pacman --noconfirm -S cinnamon arc-gtk-theme x-apps xdg-user-dirs-gtk cheese simple-scan file-roller nemo-fileroller blueberry
pacman --noconfirm -S gnome-calculator gnome-disk-utility gnome-screenshot gnome-sound-recorder gnome-terminal gnome-logs gnome-keyring yelp yelp-tools
pacman --noconfirm -S cups networkmanager bluez-utils bluez system-config-printer
pacman --noconfirm -S sound-theme-elementary kvantum-qt5 lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings
systemctl enable NetworkManager
systemctl enable lightdm
systemctl enable cups
systemctl enable avahi-daemon
systemctl enable bluetooth
echo "Configuring lightdm..."
sed -i "/^#greeter-session=example-gtk-gnome/c\greeter-session=lightdm-gtk-greeter" /etc/lightdm/lightdm.conf
echo [greeter] > /etc/lightdm/lightdm-gtk-greeter.conf
cat <<EOT >> /etc/lightdm/lightdm-gtk-greeter.conf
background = /usr/share/backgrounds/gnome/LightBulb.jpg
theme-name = Arc-Dark
icon-theme-name = Numix-Square
font-name = DejaVu Sans 12
indicators = ~host;~spacer;~clock;~power
clock-format = %a, %b %-e %-l:%M %p /etc/lightdm/lightdm-gtk-greeter.conf
position = 20%,center 50%,center
hide-user-image = true
cursor-theme-name = Vanilla-DMZ
EOT
usermod -a -G $NEWUSER lightdm
chmod g+rx /home/$NEWUSER
echo "export QT_STYLE_OVERRIDE=kvantum" >> /etc/profile
echo "load-sample-lazy x11-bell /usr/share/sounds/elementary/stereo/bell.wav" >> /etc/pulse/default.pa
echo "load-module module-x11-bell sample=x11-bell" >> /etc/pulse/default.pa
mkdir -p /etc/skel/.local/share/xed/styles
cp /mnt/xed-arc-color-theme.xml /etc/skel/.local/share/xed/styles/xed-arc-color-theme.xml
cp /mnt/bash.bashrc /etc/bash.bashrc
cp /mnt/bash.bashrc /etc/skel/.bashrc
cp /mnt/bash_aliases /mnt/etc/skel/.bash_aliases
reboot
