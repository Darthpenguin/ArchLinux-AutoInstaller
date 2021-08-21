#!/bin/sh
sudo timedatectl set-ntp
sudo pacman-key --populate archlinux
sudo pacman -Syyu
sudo pacman -S git
cd $HOME
git clone https://aur.archlinux.org/pacaur.git
git clone https://aur.archlinux.org/auracle-git.git
cd $HOME/auracle-git
makepkg -si
cd $HOME/pacaur
makepkg -si
cd $HOME
sudo rm -rf auracle-git
sudo rm -rf pacaur
sudo bash -c "echo displaybuildfiles=none >> /etc/xdg/pacaur/config"
pacaur --noconfirm -S gnome-terminal-transparency
pacaur --noconfirm -S google-chrome
pacaur --noconfirm -S pamac-aur 
pacaur --noconfirm -S noto-fonts-emoji noto-fonts noto-fonts-cjk 
pacaur --noconfirm -S numix-circle-icon-theme-git numix-square-icon-theme numix-folders-git 
pacaur --noconfirm -S xviewer xplayer pix cinnamon-sound-effects gnome-logs-git
