#!/bin/bash
#
# Perform the partitionning.

CONFIG_FILES="src/2_chroot.sh src/3_configure.sh resources/iptables.rules"

#######################################
# Print an error and exit the script.
# Arguments:
#   All the strings
# Returns:
#   Exit the script status 1
#######################################
function error() {
  echo "\n[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
  exit 1
}

#######################################
# Install required dependencies.
#######################################
function install_dependencies() {
  apt-get -y install parted coreutils curl
}

#######################################
# Ensure the programs and configuration files needed to execute are available.
# Globals:
#   CONFIG_FILES
#   CONF_FILE
# Arguments:
#   Configuration file, a path
#######################################
function check_dependencies() {
  CONFIG_FILES="$CONFIG_FILES $1"

  local FILES=(${CONFIG_FILES})
  for f in ${FILES[@]}
  do
      [[ -f $f  ]] || error "Missing configuration file: $f"
  done
  CONF_FILE="$1"

  local PROGS="bootctl parted mkfs.ext4 mount umount lsblk"
  which ${PROGS} > /dev/null 2>&1 || error "Searching PATH fails to find executables among: ${PROGS}"
}

#######################################
# Load configuration options.
# Globals:
#   CONF_FILE
#######################################
function load_config() {
  source ${CONF_FILE}

  [[ -b ${BLOCK_DEVICE} ]] || error "${BLOCK_DEVICE} is not a block device"
  [[ -n ${HOST} && -n ${USER} && -n ${T_ZONE} ]] || error "One or more configuration options empty or unset"
}

#######################################
# Prepare the partitions and build a MBR partition scheme suitable for BIOS boot.
# Globals:
#   BLOCK_DEVICE
#   ROOT_PART
#   ROOT_PARTUUID
#######################################
function prepare_partions() {
  ROOT_PART="${BLOCK_DEVICE}1"
  parted --script "${BLOCK_DEVICE}" mklabel msdos
  parted --script --align optimal "${BLOCK_DEVICE}" mkpart primary ext4 0% 100%
  mkfs.ext4 -F -L SYSTEM "${ROOT_PART}"
  ROOT_PARTUUID=$(lsblk --noheadings --output PARTUUID ${ROOT_PART})
}

#######################################
# Download Archlinux bootstrap for the chroot
#######################################
function download_bootstrap() {
  rm -fr root.x86_64 archlinux-bootstrap-2020.09.01-x86_64.tar.gz
  curl -O https://mirror.aktkn.sg/archlinux/iso/2020.09.01/archlinux-bootstrap-2020.09.01-x86_64.tar.gz
  tar xf archlinux-bootstrap-2020.09.01-x86_64.tar.gz
}

#######################################
# Prepare the chroot environmnent by copying the configuration files.
# Globals:
#   CONFIG_FILES
#######################################
function prepare_chroot() {
  local FILES=(${CONFIG_FILES})
  for f in ${FILES[@]}; do
    cp -p $f root.x86_64
  done
}

#######################################
# Entry point.
# Arguments:
#   A configuration file, a path
#######################################
function main() {
  install_dependencies
  check_dependencies "$@"
  load_config
  prepare_partions
  download_bootstrap
  prepare_chroot
  root.x86_64/bin/arch-chroot root.x86_64 ./2_chroot.sh $ROOT_PARTUUID $CONF_FILE
  echo -e "\n\n\nWake up, Neo... The installation is done!"
}

main "$@"
