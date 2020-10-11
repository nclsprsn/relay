#!/bin/bash
#
# Install an environment to allow the installation of Archlinux.

CONFIG_FILES="3_configure.sh iptables.rules"

#######################################
# Ensure the programs and configuration files needed to execute are available.
# Globals:
#   CONFIG_FILES
#   CONF_FILE
# Arguments:
#   Configuration file, a path
#######################################
function check_dependencies() {
  echo $2
  CONFIG_FILES="$CONFIG_FILES $2"

  local FILES=(${CONFIG_FILES})
  for f in ${FILES[@]}
  do
      [[ -f $f  ]] || error "Missing configuration file: $f"
  done
  CONF_FILE="$2"
}

#######################################
# Load configuration options.
# Globals:
#   CONF_FILE
#######################################
function load_config() {
  source ${CONF_FILE}
}

#######################################
# Mount the disks.
# Globals:
#   BLOCK_DEVICE
#######################################
function mount_disks() {
  mount -o discard,noatime ${BLOCK_DEVICE}1 /mnt 
}

#######################################
# Configure Pacman.
#######################################
function configure_pacman() {

  cat << EOF > /etc/pacman.conf
[options]
HoldPkg     = pacman glibc
Architecture = auto

Color
TotalDownload

SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[community]
Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist

EOF

  echo 'Server = http://mirror.aktkn.sg/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
  pacman-key --init
  pacman-key --populate archlinux
  pacman -Sy --noconfirm archlinux-keyring
}

#######################################
# Create the Archlinux system.
# Globals:
#   ADD
#######################################
function build_arch() {
  pacstrap /mnt base linux linux-firmware ${ADD}
  genfstab -U /mnt >> /mnt/etc/fstab
}

#######################################
# Copy required files into chroot.
# Globals:
#   CONFIG_FILES
#######################################
function pre_chroot() {
  local FILES=(${CONFIG_FILES})
  for f in ${FILES[@]}; do
    cp -p /$f /mnt
  done
}

#######################################
# Chroot into the new Archlinux.
#######################################
function chroot() {
  bin/arch-chroot /mnt ./3_configure.sh $1 $2
}

#######################################
# Cleanup, unmount & poweroff or reboot.
# Globals:
#   CONFIG_FILES
#######################################
function post_chroot() {
  local FILES=(${CONFIG_FILES})
  for f in ${FILES[@]}; do
      rm -f /mnt/$f
  done
  umount /mnt
}

#######################################
# Entry point.
# Arguments:
#   A configuration file, a path
#######################################
function main() {
  check_dependencies "$@"
  load_config
  mount_disks
  configure_pacman
  build_arch
  pre_chroot
  chroot "$@"
  post_chroot
}

main "$@"
