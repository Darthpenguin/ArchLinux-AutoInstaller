#!/bin/bash
lspci -v | egrep -i --color 'vga|3d|2d' | grep "Intel Corporation HD Graphics" &> /dev/null
if [ $? == 0 ]; then
   pacman -S xf86-video-intel
fi
lspci -v | egrep -i --color 'vga|3d|2d' | grep "AMD" &> /dev/null
if [ $? == 0 ]; then
  pacman -S xf86-video-amdgpu
fi
pacman -S cups man xorg-server xorg-twm xterm xcursor-vanilla-dmz xf86-input-libinput
pacman -S cinnamon arc-gtk-theme xed xreader lightdm lightdm-gtk-greeter xdg-user-dirs xdg-user-dirs-gtk
pacman -S cheese baobab simple-scan file-roller gnome-calculator gnome-disk-utility yelp gnome-screenshot gnome-sound-recorder gnome-terminal gnome-logs meson

pacaur -S archlinux-appstream-data-pamac gnome-logs-git google-chrome lightdm-settings lightdm-slick-greeter numix-circle-icon-theme-git numix-folders-git pamac-all pix xplayer xviewer

systemctl enable NetworkManager
systemctl enable lightdm
systemctl enable cups
systemctl enable avahi-daemon
