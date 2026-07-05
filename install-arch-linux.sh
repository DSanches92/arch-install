#!/usr/bin/env bash
# install-arch-linux.sh - Versão ArchMaster otimizada (Ryzen + NVIDIA)

set -euo pipefail

# ==================== CONFIGURAÇÕES ====================
DISK=""                    # Será detectado
HOSTNAME="archmaster"
USERNAME="seuusuario"      # ← Mude aqui
TIMEZONE="America/Sao_Paulo"
LOCALE="pt_BR.UTF-8"
KEYMAP="br-abnt2"
# Senhas (mude depois do boot!)
USER_PASSWORD="12345"
ROOT_PASSWORD="12345"

# =====================================================

if systemd-detect-virt --chroot >/dev/null 2>&1; then
  echo "=== MODO CHROOT ==="
  IN_CHROOT=1
else
  echo "=== MODO LIVE USB ==="
  IN_CHROOT=0
fi

# ===================== PARTE 1 - LIVE =====================
if (( IN_CHROOT == 0 )); then
  loadkeys "$KEYMAP"
  timedatectl set-ntp true
  reflector --country Brazil --latest 10 --sort rate --save /etc/pacman.d/mirrorlist

  ping -c 3 archlinux.org || { echo "Sem internet"; exit 1; }

  # Particionamento (ajustado para seu NVMe)
  echo "Discos disponíveis:"
  lsblk -d -o NAME,SIZE,TYPE,MODEL

  read -rp "Disco alvo (ex: nvme0n1): " DISK_INPUT
  DISK="/dev/${DISK_INPUT##*/}"

  echo "ATENÇÃO: TODOS OS DADOS EM $DISK SERÃO APAGADOS!"
  read -rp "Confirmar? (s/N): " confirma
  [[ "\( confirma" =\~ ^[Ss] \) ]] || exit 1

  wipefs -a "$DISK"
  sfdisk "$DISK" <<EOF
label: gpt
size=512M, type=uefi, name=EFI
type=linux, name=ArchRoot
EOF

  EFI="${DISK}p1"
  ROOT="${DISK}p2"

  mkfs.fat -F32 -n EFI "$EFI"
  mkfs.btrfs -f -L ArchRoot "$ROOT"

  mount "$ROOT" /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@snapshots
  btrfs subvolume create /mnt/@var_log
  btrfs subvolume create /mnt/@var_cache
  umount /mnt

  # Montagem otimizada
  mount -o noatime,compress=zstd:3,ssd,discard=async,subvol=@ "$ROOT" /mnt
  mkdir -p /mnt/{boot,home,var/log,var/cache}

  mount -o noatime,compress=zstd:3,ssd,discard=async,subvol=@home "$ROOT" /mnt/home
  mount -o noatime,compress=zstd:3,ssd,discard=async,subvol=@var_log "$ROOT" /mnt/var/log
  mount -o noatime,compress=zstd:3,ssd,discard=async,subvol=@var_cache "$ROOT" /mnt/var/cache
  mount "$EFI" /mnt/boot

  # Pacstrap otimizado
  pacstrap -K /mnt base base-devel linux-zen linux-zen-headers linux-firmware amd-ucode \
    btrfs-progs networkmanager git vim sudo nvidia nvidia-utils nvidia-settings

  genfstab -U /mnt >> /mnt/etc/fstab

  cp "$0" /mnt/root/install-arch-linux.sh
  chmod +x /mnt/root/install-arch-linux.sh

  echo "Entrando no chroot..."
  arch-chroot /mnt /root/install-arch-linux.sh
  exit 0
fi

# ===================== PARTE 2 - CHROOT =====================
echo "=== Configurando sistema ==="

ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
hwclock --systohc

sed -i "s/^#$LOCALE/$LOCALE/" /etc/locale.gen
sed -i "s/^#en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen
locale-gen

echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF

# Pacman otimizado
sed -i "s/^#Color/Color/" /etc/pacman.conf
sed -i "s/.*ParallelDownloads.*/ParallelDownloads = 15/" /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/ s/^#//" /etc/pacman.conf

pacman -Syyu --noconfirm

# Usuário
useradd -m -G wheel,audio,video,storage "$USERNAME"
echo "$USERNAME:$USER_PASSWORD" | chpasswd
echo "root:$ROOT_PASSWORD" | chpasswd
sed -i "s/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers

# Bootloader
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ArchLinux
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager

echo "Instalação base concluída!"
echo "Reinicie, remova o pendrive e logue como $USERNAME."
echo "Depois rode o install-hyprland.sh (se for usar Hyprland)."

exit 0