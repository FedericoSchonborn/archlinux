#!/usr/bin/env bash

set -euo pipefail

function phase() {
    local message="$1"

    echo -e ">> $message"
}

function step() {
    local message="$1"

    echo -e " - $message"
}

phase "Erasing disk..."
    step "Suspending into memory..."
    echo mem > /sys/power/state
    step "Setting disk password..."
    hdparm --security-set-pass eins /dev/sda
    step "Applying Security Erase (Enhanced) to disk..."
    hdparm --security-erase-enhanced eins /dev/sda

phase "Creating disk partitions..."
    step "Creating new GPT partition table..."
        sgdisk -o /dev/sda

    step "Creating boot partition..."
        sgdisk -n 0:0:+512MiB -t 0:ef00 /dev/sda

    step "Creating root partition..."
        sgdisk -n 0:0:-4GiB -t 0:8300 /dev/sda

    step "Creating swap partition..."
        sgdisk -n 0:0:0 -t 0:8200 /dev/sda

phase "Formatting disk partitions..."
    step "Formatting boot partiton..."
        mkfs.fat -F 32 /dev/sda1

    step "Formatting root partition..."
        mkfs.ext4 /dev/sda2

    step "Formatting swap partition..."
        mkswap /dev/sda3

phase "Mounting disk partitions..."
    step "Mounting root partition..."
        mount --mkdir /dev/sda2 /mnt

    step "Mounting boot partition..."
        mount --mkdir /dev/sda1 /mnt/boot

    step "Activating swap partition..."
        swapon /dev/sda3

phase "Configuring package manager..."
    step "Setting up mirror list..."
        reflector --country Chile --protocol http,https --sort rate --save /etc/pacman.d/mirrorlist

    step "Setting up Pacman..."
        sed -e "s/#Color/Color/g" -e "s/#ParallelDownloads = 5/ParallelDownloads = 4\nILoveCandy/g" -e "s/#[multilib]\n#/[multilib]\n/g" -i /etc/pacman.conf

    step "Copying local configuration to target..."
        mkdir /mnt/etc /mnt/etc/pacman.d
        cp -fv /etc/pacman.conf /mnt/etc/pacman.conf
        cp -fv /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

phase "Installing packages..."
    step "Installing base system packages..."
        pacstrap /mnt base base-devel linux linux-firmware wireless-regdb intel-ucode

    step "Installing extra system packages..."
        pacstrap /mnt nano nano-syntax-highlighting man-db man-pages reflector zsh grml-zsh-config zsh-{autosuggestions,completions,history-substring-search,syntax-highlighting}

    step "Installing filesystem support packages..."
        pacstrap /mnt btrfs-progs dosfstools exfatprogs f2fs-tools e2fsprogs jfsutils nilfs-utils reiserfsprogs udftools xfsprogs squashfs-tools erofs-utils

    step "Installing system services..."
        pacstrap /mnt networkmanager iwd modemmanager pipewire wireplumber pipewire-{alsa,pulse,v4l2,x11-bell} bluez bluez-utils cups cups-pdf cups-filters cups-pk-helper foomatic-db-engine foomatic-db foomatic-db-ppds foomatic-db-nonfree foomatic-db-nonfree-ppds ghostscript gsfonts gutenprint foomatic-db-gutenprint-ppds sane

    step "Installing language packages..."
        pacstrap /mnt aspell-es hunspell-es_{any,ar,bo,cl,co,cr,cu,do,ec,es,gt,hn,mx,ni,pa,pe,pr,py,sv,uy,ve} hyphen-es man-pages-es mythes-es

    step "Installing Xorg..."
        pacstrap /mnt xorg xorg-{apps,drivers,fonts}

    step "Installing Vulkan driver..."
        pacstrap /mnt vulkan-intel lib32-vulkan-intel

    step "Installing Noto fonts..."
        pacstrap /mnt noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra

    step "Installing GNOME Core..."
        pacstrap /mnt baobab cheese eog evince file-roller lrzip p7zip unace unrar gdm gnome-{backgrounds,boxes,calculator,calendar,characters,clocks,contacts,control-center,disk-utility,font-viewer,keyring,logs,maps,photos,remote-desktop,session,settings-daemon,shell,shell-extensions,system-monitor,user-docs,user-share,video-effects,weather} power-profiles-daemon system-config-printer usbguard gstreamer-vaapi gst-libav gst-plugin-{pipewire,va} gst-plugins-{bad,base,good,ugly} grilo-plugins dleyna-server gvfs gvfs-{afc,goa,google,gphoto2,mtp,nfs,smb} mutter nautilus nautilus-sendto orca rygel tumbler simple-scan sushi unoconv totem vino xdg-user-dirs-gtk yelp xdg-desktop-portal xdg-desktop-portal-gnome

    step "Installing GNOME Extra..."
        pacstrap /mnt geary gnome-{sound-recorder,tweaks}

    step "Installing additional package groups..."
        pacstrap /mnt fprint libretro

    step "Installing additional software..."
        pacstrap /mnt bitwarden firefox firefox-i18n-es-{ar,cl,es,mx} speech-dispatcher telegram-desktop discord element-desktop libreoffice-fresh libreoffice-fresh-es beanshell coin-or-mp java-environment java-runtime libpaper libwpg mariadb-libs postgresql-libs pstoedit unixodbc steam steam-native-runtime gimp gimp-plugin-gmic curl poppler-glib gimp-help-es inkscape fig2dev pstoedit scour github-cli podman podman-docker podman-compose netavark

phase "Configuring target system..."
    step "Setting up /etc/fstab..."
        genfstab -U /mnt >> /mnt/etc/fstab

    step "Setting up time zone..."
        ln -sf /usr/share/zoneinfo/America/Argentina/Buenos_Aires /etc/localtime
        hwclock --systohc

    step "Generating locales..."
        cat <<EOF > /etc/locale.gen
en_US.UTF-8
es_AR.UTF-8
EOF
        locale-gen

    step "Setting locales..."
        cat <<EOF > /etc/locale.conf
LANG="es_AR.UTF-8"
EOF

    step "Setting keyboard layout..."
        cat <<EOF > /etc/vconsole.conf
KEYMAP="la-latin1"
EOF
        cat <<EOF > /etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "latam"
EndSection
EOF

    step "Setting hostname..."
        cat <<EOF > /etc/hostname
Swift-SF314-52
EOF

    step "Setting up bootloader..."
        bootctl install
        cat <<EOF > /boot/loader/loader.conf
default arch.conf
timeout 0
editor no
EOF
        cat <<EOF > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=/dev/sda2 rw
EOF
        cat <<EOF > /boot/loader/entries/arch-fallback.conf
title   Arch Linux (fallback initramfs)
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux-fallback.img
options root="LABEL=arch_os" rw
EOF

    step "Adding users..."
        useradd -c "Federico Damián" -G wheel -m -s /bin/zsh federico
        passwd federico

    step "Enabling services..."
        for service in bluetooth cups gdm NetworkManager ModemManager; do
            systemctl enable "$service"
        done
