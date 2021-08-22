#!/bin/sh
gsettings set org.cinnamon.theme name "Arc-Dark"
gsettings set org.cinnamon.desktop.interface gtk-theme "Arc-Dark"
gsettings set org.cinnamon.desktop.wm.preferences theme "Arc-Dark"
gsettings set org.gnome.desktop.background picture-uri file://///usr/share/backgrounds/gnome/LightBulb.jpg
sudo timedatectl set-ntp true
sudo pacman --noconfirm -Syyu
sudo pacman --noconfirm -S git
cd $HOME
git clone https://aur.archlinux.org/pacaur.git
git clone https://aur.archlinux.org/auracle-git.git
cd $HOME/auracle-git
makepkg --noconfirm -si
cd $HOME/pacaur
makepkg --noconfirm -si
cd $HOME
sudo rm -rf $HOME/auracle-git
sudo rm -rf $HOME/pacaur
sudo bash -c "echo displaybuildfiles=none >> /etc/xdg/pacaur/config"
pacaur --noconfirm -S gnome-terminal-transparency
pacaur --noconfirm -S google-chrome
pacaur --noconfirm -S pamac-aur 
pacaur --noconfirm -S noto-fonts-emoji noto-fonts noto-fonts-cjk 
pacaur --noconfirm -S numix-circle-icon-theme-git numix-square-icon-theme numix-folders-git
gsettings set org.cinnamon.desktop.interface icon-theme 'Numix-Circle'
sudo pacman-key --populate archlinux
pacaur --noconfirm -S xviewer xplayer pix cinnamon-sound-effects gnome-logs-git redshift-gtk-git
