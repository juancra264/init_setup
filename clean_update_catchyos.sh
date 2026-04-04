#!/bin/bash

sudo rm -rf /etc/pacman.d/gnupg/
sudo pacman-key --init
sudo pacman-key --populate archlinux cachyos
sudo pacman -Sy archlinux-keyring cachyos-keyring --noconfirm
sudo pacman -Syyu --noconfirm
paru -Syu --noconfirm
