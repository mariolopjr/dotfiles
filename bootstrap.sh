#!/usr/bin/env -S bash -e

# Cleaning the TTY.
clear

# Pretty print (function).
print () {
    echo -e "\e[1m\e[93m[ \e[92m•\e[93m ] \e[4m$1\e[0m"
}

# Prepare system for install
bash <(curl -sL git.io/JMnfF)

# Enable multilib repo
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf

# Install NVIDIA proprietary driver if necessary
read -r -p "Do you want to install nvidia proprietary driver? [y/N]? " response
response=${response,,}
if [[ "$response" =~ ^(yes|y)$ ]]; then
    print "Installing nvidia driver."
    pacstrap /mnt nvidia nvidia-utils nvidia-settings
    echo "MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)" >> /mnt/etc/mkinitcpio.conf

    print "Rebuilding initramfs"
    arch-chroot /mnt mkinitcpio -P &>/dev/null
    
    print "Configuring pacman initramfs rebuild on nvidia driver update"
    cat > /mnt/etc/pacman.d/hooks/60-nvidia.hook <<EOF
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia
Target=linux

[Action]
Description=Update Nvidia module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case $trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'
EOF
fi

# Install packages
pacstrap /mnt \
	kitty fish chezmoi pacman-contrib fwupd openssh \
    gnome gnome-extra \
	pipewire wireplumber pipewire-pulse firejail apparmor dnsmasq cifs-utils

# Enable services
for service in sshd gdm
do
    systemctl enable "$service" --root=/mnt &>/dev/null
done
