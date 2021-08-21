#!/bin/sh
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
pacaur --noconfirm -S bash-completion gnome-terminal-transparency google-chrome pamac-aur ttf-dejavu noto-fonts-emoji noto-fonts noto-fonts-cjk numix-circle-icon-theme-git numix-square-icon-theme numix-folders-git system-config-printer xviewer xplayer pix lightdm-gtk-greeter-settings gnome-keyring blueberry cinnamon-sound-effects gnome-logs-git nemo-fileroller gnome-usage
