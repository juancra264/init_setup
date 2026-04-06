#!/bin/bash

# Install Hyprland and Essentials:
sudo pacman -S hyprland waybar wofi rofi mako kitty --noconfirm
# CachyOS Settings
sudo pacman -S cachyos-hyprland-settings --noconfirm
# Install monitor manager
sudo pacman -S nwg-displays --noconfirm

# Display what Monitor
hyprctl monitors
