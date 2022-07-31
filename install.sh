#!/usr/bin/env bash

set -euo pipefail

DEVICE="${DEVICE:-/dev/sda}"
TARGET="${TARGET:-/mnt/target}"
KERNEL="${KERNEL:-linux}"

function @phase() {
    local message="$1"

    echo -e ">> $message"
}

function @step() {
    local _message="$1"

    echo -e " - ${_message}"
}

function @chroot() {
    local _command="$1"

    arch-chroot "$TARGET" /bin/bash -c "${_command}"
}

@phase "Creating disk partitions..."
    @step "Creating new GPT partition table..."
        sgdisk -o "$DEVICE"

    @step "Creating boot partition..."
        sgdisk -n 0:0:+512MiB -t 0:ef00 "$DEVICE"

    @step "Creating root partition..."
        sgdisk -n 0:0:-4GiB -t 0:8300 "$DEVICE"

    @step "Creating swap partition..."
        sgdisk -n 0:0:0 -t 0:8200 "$DEVICE"

@phase "Formatting disk partitions..."
    @step "Formatting boot partiton..."
        mkfs.fat -F 32 "$DEVICE"1

    @step "Formatting root partition..."
        mkfs.ext4 "$DEVICE"2

    @step "Formatting swap partition..."
        mkswap "$DEVICE"3

@phase "Mounting disk partitions..."
    @step "Mounting root partition..."
        mount --mkdir "$DEVICE"2 "$TARGET"

    @step "Mounting boot partition..."
        mount --mkdir "$DEVICE"1 "$TARGET"/boot

    @step "Activating swap partition..."
        swapon "$DEVICE"3

@phase "Configuring package manager..."
    @step "Setting up mirror list..."
        reflector --country Chile --protocol http,https --sort rate --save /etc/pacman.d/mirrorlist

    @step "Setting up Pacman..."
        nano /etc/pacman.conf

    @step "Copying local configuration to target..."
        mkdir -pv "$TARGET"/etc "$TARGET"/etc/pacman.d
        cp -fv /etc/pacman.conf "$TARGET"/etc/pacman.conf
        cp -fv /etc/pacman.d/mirrorlist "$TARGET"/etc/pacman.d/mirrorlist

@phase "Installing packages..."
    @step "Installing base system packages..."
        pacstrap -i "$TARGET" base base-devel "$KERNEL" linux-firmware wireless-regdb intel-ucode

    @step "Installing extra system packages..."
        pacstrap -i "$TARGET" nano nano-syntax-highlighting man-db man-pages reflector zsh grml-zsh-config zsh-{autosuggestions,completions,history-substring-search,syntax-highlighting}

    @step "Installing filesystem support packages..."
        pacstrap -i "$TARGET" btrfs-progs dosfstools exfatprogs f2fs-tools e2fsprogs jfsutils nilfs-utils reiserfsprogs udftools xfsprogs squashfs-tools erofs-utils

    @step "Installing system services..."
        pacstrap -i "$TARGET" networkmanager iwd modemmanager pipewire wireplumber pipewire-{alsa,pulse,v4l2,x11-bell} bluez bluez-utils cups cups-pdf cups-filters cups-pk-helper foomatic-db-engine foomatic-db foomatic-db-ppds foomatic-db-nonfree foomatic-db-nonfree-ppds ghostscript gsfonts gutenprint foomatic-db-gutenprint-ppds sane

    @step "Installing language packages..."
        pacstrap -i "$TARGET" aspell-es hunspell-es_{any,ar,bo,cl,co,cr,cu,do,ec,es,gt,hn,mx,ni,pa,pe,pr,py,sv,uy,ve} hyphen-es man-pages-es mythes-es

    @step "Installing Xorg..."
        pacstrap -i "$TARGET" xorg xorg-{apps,drivers,fonts}

    @step "Installing Noto fonts..."
        pacstrap -i "$TARGET" noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra

    @step "Installing KDE Plasma"
        pacstrap -i "$TARGET" bluedevil breeze kcmutils breeze-gtk xsettingsd drkonqi kactivitymanagerd kde-cli-tools kde-gtk-config kdecoration kdeplasma-addons purpose qt5-webengine quota-tools kgamma5 khotkeys kinfocenter kmenuedit kscreen kscreenlocker ksshaskpass ksystemstats networkmanager-qt kwallet-pam kwayland-integration kwin maliit-keyboard kwrited layer-shell-qt libkscreen libksysguard milou oxygen oxygen-sounds plasma-browser-integration plasma-desktop kaccounts-integration plasma-disks plasma-firewall plasma-integration plasma-nm plasma-pa plasma-systemmonitor plasma-workspace appmenu-gtk-module baloo plasma-workspace-wallpapers polkit-kde-agent powerdevil kinfocenter power-profile-daemon sddm-kcm systemsettings xdg-desktop-portal-kde

    #@step "Installing GNOME Core..."
        #pacstrap -i "$TARGET" baobab cheese eog evince file-roller lrzip p7zip unace unrar gdm gnome-{backgrounds,boxes,calculator,calendar,characters,clocks,contacts,control-center,disk-utility,font-viewer,keyring,logs,maps,photos,remote-desktop,session,settings-daemon,shell,shell-extensions,system-monitor,user-docs,user-share,video-effects,weather} power-profiles-daemon system-config-printer usbguard gstreamer-vaapi gst-libav gst-plugin-{pipewire,va} gst-plugins-{bad,base,good,ugly} grilo-plugins dleyna-server gvfs gvfs-{afc,goa,google,gphoto2,mtp,nfs,smb} mutter nautilus nautilus-sendto orca rygel tumbler simple-scan sushi unoconv totem vino xdg-user-dirs-gtk yelp xdg-desktop-portal xdg-desktop-portal-gnome

    @step "Installing KDE Applications (Graphics)"
        pacstrap -i "$TARGET" gwenview kimageformats qt5-imageformats kamera kdegraphics-thumbnailers okular chmlib ebook-tools kdegraphics-mobipocket khtml libzip unrar spectacle svgpart

    @step "Installing KDE Applications (Multimedia)"
        pacstrap -i "$TARGET" audiocd-kio opus-tools elisa ffmpegthumbs

    @step "Installing KDE Applications (Network)"
        pacstrap -i "$TARGET" kdeconnect qt5-tools sshfs kio-extras icoutils kactivities-stats libappimage openexr taglib kio-gdrive

    @step "Installing KDE Applications (System)"
        pacstrap -i "$TARGET" dolphin khelpcenter ksystemlog partitionmanager

    @step "Installing KDE Applications (Utilities)"
        pacstrap -i "$TARGET" ark lrzip lzop p7zip kdialog kfind mlocate konsole keditbookmarks kwalletmanager kwrite markdownpart print-manager system-config-printer

    #@step "Installing GNOME Extra..."
        #pacstrap -i "$TARGET" geary gnome-{sound-recorder,tweaks}

    @step "Installing additional package groups..."
        pacstrap -i "$TARGET" fprint libretro

    @step "Installing additional software..."
        pacstrap -i "$TARGET" vlc bitwarden firefox firefox-i18n-es-{ar,cl,es,mx} speech-dispatcher telegram-desktop discord element-desktop libreoffice-fresh libreoffice-fresh-es beanshell coin-or-mp java-environment java-runtime libpaper libwpg mariadb-libs postgresql-libs pstoedit unixodbc steam steam-native-runtime gimp gimp-plugin-gmic curl poppler-glib gimp-help-es inkscape fig2dev pstoedit scour github-cli podman podman-docker podman-compose netavark

    @step "Installing development tools..."
        pacstrap -i "$TARGET" rustup go

@phase "Configuring target system..."
    @step "Setting up /etc/fstab..."
        genfstab -U "$TARGET" >> "$TARGET"/etc/fstab

    @step "Setting up time zone..."
        @chroot "ln -sf /usr/share/zoneinfo/America/Argentina/Buenos_Aires /etc/localtime"
        @chroot "hwclock --systohc"

    @step "Generating locales..."
        @chroot "cat <<EOF > /etc/locale.gen
en_US.UTF-8 UTF-8
es_AR.UTF-8 UTF-8
EOF"
        @chroot locale-gen

    @step "Setting locales..."
        @chroot "cat <<EOF > /etc/locale.conf
LANG=\"es_AR.UTF-8\"
EOF"

    @step "Setting keyboard layout..."
        @chroot "cat <<EOF > /etc/vconsole.conf
KEYMAP=\"la-latin1\"
EOF"
	    @chroot "mkdir -p /etc/X11/xorg.conf.d"
        @chroot "cat <<EOF > /etc/X11/xorg.conf.d/00-keyboard.conf
Section \"InputClass\"
        Identifier \"system-keyboard\"
        MatchIsKeyboard \"on\"
        Option \"XkbLayout\" \"latam\"
EndSection
EOF"

    @step "Setting hostname..."
        @chroot "cat <<EOF > /etc/hostname
Swift-SF314-52
EOF"

    @step "Setting up bootloader..."
        @chroot "bootctl install"
        @chroot "cat <<EOF > /boot/loader/loader.conf
default arch.conf
timeout 0
editor no
EOF"
        @chroot "cat <<EOF > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-${KERNEL}
initrd  /intel-ucode.img
initrd  /initramfs-${KERNEL}.img
options root=\"${DEVICE}2\" rw
EOF"
        @chroot "cat <<EOF > /boot/loader/entries/arch-fallback.conf
title   Arch Linux (fallback initramfs)
linux   /vmlinuz-${KERNEL}
initrd  /intel-ucode.img
initrd  /initramfs-${KERNEL}-fallback.img
options root=\"${DEVICE}2\" rw
EOF"

    @step "Adding users..."
        @chroot "useradd -c \"Federico Damián\" -G wheel -m -s /bin/zsh federico"
        @chroot "passwd federico"

    @step "Enabling services..."
        # shellcheck disable=SC2016,SC2154
        @chroot "for service in bluetooth cups sddm NetworkManager ModemManager; do
            systemctl enable ${service}
        done"
