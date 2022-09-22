#!/bin/bash

dirname=$(dirname "$0")

# --- Packages

while getopts ":carlh" o; do
    case "${o}" in
        a)
            addons_open=1
            ;;
        c)
            configure_only=1
            ;;
        r)
            reload_all=1
            ;;
        l)
            laptop=1
            ;;
        h)
            echo "./configure.sh [options]"
            echo "-c        Load only configs       (no package downloads)"
            echo "-a        Load addons             (requires open sway)"
            echo "-r        Reload all configs      (requires open sway)"
            echo "-l        Laptop configuration"
            echo "-h        Displays this message"
            exit 0
            ;;
    esac
done
shift $((OPTIND-1))

# Official packages
official=(
    # Manuals
    man-db

    # Fonts
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    otf-font-awesome

    # Sway
    xorg-xwayland
    waybar
    wl-clipboard
    libnotify
    mako

    # Sound
    alsa-utils
    pavucontrol
    pipewire
    wireplumber
    helvum
    pipewire-alsa
    pipewire-pulse
    pipewire-jack
    easyeffects
    noise-suppression-for-voice

    # Screen recording
    grim
    slurp
    xdg-desktop-portal
    xdg-desktop-portal-wlr

    # Tools
    tmux
    stress
    ffmpeg
    git
    p7zip
    lm_sensors
    openssh
    xdg-utils
    solaar
    ntfs-3g

    # Apps
    discord
    firefox
    gimp
    mpv

    # Theme
    breeze-gtk
    breeze-icons

    # IME
    fcitx5-im
    fcitx5-mozc
    fcitx5-nord
)

# Intel GPU
intel_gpu=$(lspci -nn | grep VGA | grep -i intel)
if [[ $intel_gpu ]] ; then
    official+=(
        mesa
        vulkan-intel
        intel-media-driver
        intel-gpu-tools
        libva-utils
    )
else
    echo "Intel GPU not detected. Please install appropriate drivers manually."
fi

# Laptop
if [[ $laptop == 1 ]] ; then
    official+=(
        thermald
    )
fi

# AUR packages
aur=(
    # Sway
    wlroots-git
    swaybg-git
    sway-git

    # Apps
    visual-studio-code-bin
    spotify

    # Tools
    yt-dlp

    # Sway stuff
    foot
    sway-launcher-desktop
)

if [[ ! $configure_only ]] ; then
    # Refresh pacman
    sudo pacman -Syy

    # yay from AUR
    if ! yay -V > /dev/null ; then
        sudo pacman --noconfirm -S --needed git
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg --noconfirm -si
        cd ..
        rm -rf yay
    fi

    sudo pacman --noconfirm -S --needed ${official[@]}
    yay --noconfirm -S --needed ${aur[@]}

    # Enable services
    if [[ $laptop == 1 ]] ; then
        sudo systemctl enable thermald.service
        sudo systemctl start thermald.service
    fi

    # Start pipewire after install
    systemctl --user start pipewire-pulse.service

else
    echo "Only config updates"
fi

# --- Config

# Make dirs
mkdir -p ~/.config
mkdir -p ~/.config/sway
mkdir -p ~/.config/waybar
mkdir -p ~/.config/gtk-3.0
mkdir -p ~/.config/environment.d
mkdir -p ~/.mozilla
mkdir -p ~/.mozilla/firefox
mkdir -p ~/.config/fcitx5
mkdir -p ~/.config/fcitx5/conf
mkdir -p ~/.config/mako
mkdir -p ~/.config/Code/User/
mkdir -p ~/.config/spotify
mkdir -p ~/.config/pipewire/pipewire.conf.d

# Copy files
cp ${dirname}/config/sway/* ~/.config/sway/
cp ${dirname}/config/waybar/* ~/.config/waybar/
cp ${dirname}/config/gtk/gtk2 ~/.gtkrc-2.0
cp ${dirname}/config/gtk/gtk3 ~/.config/gtk-3.0/settings.ini
cp ${dirname}/config/bash/bashrc ~/.bashrc
cp ${dirname}/config/environment/systemd ~/.config/environment.d/env.conf
cp ${dirname}/config/fcitx5/profile ~/.config/fcitx5/
cp ${dirname}/config/fcitx5/classicui.conf ~/.config/fcitx5/conf/
cp ${dirname}/config/mako/config ~/.config/mako/
cp ${dirname}/config/vscode/settings.json ~/.config/Code/User/
cp ${dirname}/config/spotify/prefs ~/.config/spotify/
cp ${dirname}/config/pipewire/pipewire.conf.d/* ~/.config/pipewire/pipewire.conf.d/

# Sudo
sudo mkdir -p /etc/NetworkManager/conf.d/
sudo cp ${dirname}/config/networkmanager/dns-servers.conf /etc/NetworkManager/conf.d/
sudo cp ${dirname}/config/environment/env /etc/environment

# Images
mkdir -p ~/Images
cp ${dirname}/images/* ~/Images/

# Firefox config
firefox_profile=$(ls ~/.mozilla/firefox | grep '\.default-release$')

if [[ $firefox_profile ]] ; then
    cp ${dirname}/config/firefox/user.js ~/.mozilla/firefox/${firefox_profile}/user.js
fi

if [[ $addons_open ]] && [[ $WAYLAND_DISPLAY ]] ; then
    addon () {
        addon_id=$1
        addon_link="https://addons.mozilla.org/firefox/downloads/latest/${addon_id}/addon-${addon_id}-latest.xpi"
        echo $addon_link
    }

    addon_ublock=$(addon 607454)
    addon_h264=$(addon 1482534)
    addon_tamper=$(addon 683490)
    addon_nordvpn=$(addon 872622)

    firefox $addon_ublock $addon_h264 $addon_tamper $addon_nordvpn > /dev/null 2>&1 &
fi

# Set other settings
gsettings set org.gnome.desktop.interface gtk-theme Breeze-Dark
gsettings set org.gnome.desktop.interface icon-theme breeze-dark

xdg-settings set default-web-browser firefox.desktop
xdg-mime default firefox.desktop x-scheme-handler/http
xdg-mime default firefox.desktop x-scheme-handler/https

# Pacman
sudo sed -i -e 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# Git
test=$(git config --global user.email)
if [[ ! $test ]] ; then
    read -p "Git email: " email
    read -p "Git name: " name
    git config --global user.email "$email"
    git config --global user.name "$name"
fi

# --- Scripts
mkdir -p ~/scripts
cp ${dirname}/scripts/*.sh ~/scripts

# --- Reload needed applications

if [[ $WAYLAND_DISPLAY ]] ; then
    # Non-essential
    makoctl reload &

    # Essential
    if [[ $reload_all ]] ; then
        swaymsg reload
        systemctl --user restart pipewire-pulse.service
    fi
fi

if [[ ! $firefox_profile ]] ; then
    echo "Please re-run this script with \"-c\" after opening Firefox to apply configs."
fi
