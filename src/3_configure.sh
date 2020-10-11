#!/bin/bash
#
# Perform the configuration of the OS.

#######################################
# Check for empty input; kernel params can be empty.
# Arguments:
#   Root partition UUID
#   Configuration file, a path
#######################################
function load_config() {
  ROOT_PARTUUID="$1"
  CONF_FILE="$2"

  source ${CONF_FILE}
  echo ROOT_PARTUUID="$ROOT_PARTUUID", \
    HOST="$HOST", \
    USER="$USER", \
    T_ZONE="$T_ZONE", \
    KERNEL_PARAMS="$KERNEL_PARAMS", \
    BLOCK_DEVICE="$BLOCK_DEVICE"
}

#######################################
# Configure the timezone.
# Globals:
#   T_ZONE
#######################################
function configure_time() {
  ln --verbose --symbolic --force /usr/share/zoneinfo/${T_ZONE} /etc/localtime
  hwclock --systohc
  systemctl enable systemd-timesyncd.service
}

#######################################
# Configure the locale.
#######################################
function configure_locale() {
  sed --in-place 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
  locale-gen
  echo "LANG=en_US.UTF-8" >> /etc/locale.conf
}

#######################################
# Configure the network.
# Globals:
#   HOST
#######################################
function configure_networking() {
  echo "$HOST" >> /etc/hostname
  systemctl enable dhcpcd.service
}

#######################################
# Configure the firewall; iptables configurations.
#######################################
function configure_firewall() {
  cp ./iptables.rules /etc/iptables
  systemctl enable iptables.service
}

#######################################
# Configure the root pw, $USER account.
# Globals:
#   USER
#######################################
function configure_accounts() {
  echo "root:password" | chpasswd
  useradd --create-home --groups wheel --shell /bin/zsh "$USER"
  echo "${USER}:password" | chpasswd
}

#######################################
# Configure the sudo capability for 'wheel' group members.
#######################################
function configure_sudoers() {
  sed --in-place 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
  chown -c root:root /etc/sudoers
  chmod -c 0440 /etc/sudoers
}

#######################################
# Install and configure GRUB.
# Globals:
#   BLOCK_DEVICE
#   KERNEL_PARAMS
#######################################
function configure_grub() {
  grub-install --target=i386-pc --recheck "${BLOCK_DEVICE}"
  sed --in-place "s#quiet#${KERNEL_PARAMS}#" /etc/default/grub
  grub-mkconfig --output /boot/grub/grub.configure
}

#######################################
# Configure pacman_hook pacman cache maintenance, assumes 'pacman-contrib' package is installed
#######################################
function configure_pacman_hooks() {
  local PACCACHE_HOOK="/etc/pacman.d/hooks/paccache.hook"
  [[ ! -d "/etc/pacman.d/hooks" ]] && mkdir -p /etc/pacman.d/hooks

cat << EOF > $PACCACHE_HOOK
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Package
Target = *

[Action]
Description = Cleaning pacman cache...
When = PostTransaction
Exec = /usr/bin/paccache --remove
EOF

}

#######################################
# Configure sshd; disable root login, allow access only for $USER
# Globals:
#   USER
#######################################
function configure_sshd() {
  sed --in-place 's/^#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
  echo "AllowUsers $USER" >> /etc/ssh/sshd_config
  systemctl enable sshd.service
}

#######################################
# Configure the $USER environment
# Globals:
#   USER
#######################################
function configure_env() {
  git clone https://github.com/nclsprsn/dotfiles.git /home/${USER}/.dotfiles
  cd /home/${USER}/.dotfiles

cat << EOF > config/config.sh
#!/usr/bin/env bash

source ~/.dotfiles/config/variables.sh

#######################################################################
# Global configuration
#######################################################################

# Debian/Arch
DOTFILES_OS=$DOTFILES_VAR_ARCH
# Server/Desktop
DOTFILES_ENV=$DOTFILES_VAR_SERVER
# Admin/User/Root
DOTFILES_USER=$DOTFILES_VAR_ADMIN
# true/false
DOTFILES_STARSHIP_ENABLED=false


#######################################################################
# Installation configuration
#######################################################################

DOTFILES_EXCLUDE=( $DOTFILES_MOD_UI $DOTFILES_MOD_MUSIC $DOTFILES_MOD_SOUND $DOTFILES_MOD_VIDEO )

source ~/.dotfiles/config/functions.sh
EOF
  chown -R ${USER}:${USER} /home/${USER}/.dotfiles
  sudo -u ${USER} sh "./INSTALL.sh"
}

#######################################
# Clean Archlinux
# Globals:
#   REMOVE
#######################################
function clean() {
  [[ ! -z "$REMOVE" ]] && pacman -Rns ${REMOVE}
}

#######################################
# Entry point.
# Arguments:
#   A configuration file, a path
#######################################
function main() {
  load_config "$@"
  configure_time
  configure_locale
  configure_networking
  configure_firewall
  configure_accounts
  configure_sudoers
  configure_grub
  configure_pacman_hooks
  configure_sshd
  configure_env
  clean
}

main "$@"
