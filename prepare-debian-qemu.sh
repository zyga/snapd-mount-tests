#!/bin/sh
set -xeu
# This script prepares an image built with autopkgtest-build-qemu to work with spread.
chroot "$ROOT" apt update
# Spread assumes the user uses bash.
chroot "$ROOT" chsh --shell /bin/bash user
# Spread connects over ssh.
chroot "$ROOT" sh -c 'DEBIAN_FRONTEND=noninteractive apt install -y ssh'
# Spread requires the user to have a non-empty password for ssh.
echo 'user:user' | chroot "$ROOT" chpasswd
# Spread depends on sudo when running tests as a non-root user.
chroot "$ROOT" sh -c 'DEBIAN_FRONTEND=noninteractive apt install -y sudo'
# Spread requires the user to have access to sudo without password.
echo '%sudo  ALL=(ALL) NOPASSWD: ALL' | chroot "$ROOT" tee /etc/sudoers.d/spread
chroot "$ROOT" usermod --append --groups sudo user
