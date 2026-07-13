#!/usr/bin/env bash
#
# Script de Pós-Instalação — Arch Linux + BTRFS
# Hardware: Ryzen 5 3600 · RTX 2060 · NVMe 1TB · 16GB RAM
#
# Executa Parte 1 (live) -> chroot -> Parte 2 automaticamente
# Depois: logar como usuário e rodar script "post-install.sh"
#
# Adicione esse script dentro do pen-drive bootável com Arch Linux.
#

set -euo pipefail

echo ""
echo "                             ###                ###       ##                               "
echo "                              ##                 ##                                        "
echo "   ####    ######    ####     ##                 ##      ###     #####    ##  ##   ##  ##  "
echo "      ##    ##  ##  ##  ##    #####              ##       ##     ##  ##   ##  ##    ####   "
echo "   #####    ##      ##        ##  ##             ##       ##     ##  ##   ##  ##     ##    "
echo "  ##  ##    ##      ##  ##    ##  ##             ##       ##     ##  ##   ##  ##    ####   "
echo "   #####   ####      ####    ###  ##            ####     ####    ##  ##    ######  ##  ##  "
echo ""
echo "INSTALAÇÃO DO ARCH + BTRFS"
echo "   Pt.01 - INSTALAÇÃO DA BASE"
echo "   Pt.02 - CONFIGURAÇÕES PRÉ REINICIALIZAÇÃO"
echo ""

#------------------------------------------------------------------------------#
#                            CONFIGURAÇÕES INICIAIS                            #
#------------------------------------------------------------------------------#

DISK=""
HOSTNAME="dsanches"
USERNAME="danilo"
TIMEZONE="America/Sao_Paulo"
LOCALE="pt_BR.UTF-8"
LOCALE_FALLBACK="en_US.UTF-8"
KEYMAP="br-abnt2"
USER_PASSWORD="12345"
ROOT_PASSWORD="12345"

#------------------------------------------------------------------------------#
#                              DETECTAR AMBIENTE                               #
#------------------------------------------------------------------------------#
if systemd-detect-virt --chroot >/dev/null 2>&1; then
  echo "=== MODO CHROOT ==="
  echo ""
  IN_CHROOT=1
else
  echo "=== MODO LIVE USB ==="
  echo ""
  IN_CHROOT=0
fi

#------------------------------------------------------------------------------#
#                              PARTE 1 - LIVE USB                              #
#------------------------------------------------------------------------------#
if (( IN_CHROOT == 0 )); then

  # Verifica se está em modo UEFI (obrigatório para este script)
  if [[ ! -d /sys/firmware/efi ]]; then
    echo ""
    echo " :: ERRO: Sistema não foi inicializado em modo UEFI."
    echo " :: Este script requer UEFI. Reinicie e selecione UEFI na BIOS."
    echo ""
    exit 1
  fi

  loadkeys "$KEYMAP"
  timedatectl set-ntp true

  ping -c 4 archlinux.org >/dev/null || { echo " :: Sem internet"; exit 1; }

  pacman -Syy --noconfirm

  echo ""
  echo " :: Discos disponíveis:"
  echo " :: -------------------"
  lsblk -d -o NAME,SIZE,TYPE,MODEL | grep -v '^NAME' | grep disk
  echo ""

  while true; do
    read -r -p "Digite o disco alvo (ex: /dev/nvme0n1 ou /dev/sda): " DISK_INPUT

    DISK="/dev/${DISK_INPUT##*/}"
    if [[ ! -b "$DISK" ]]; then
      echo " :: Erro: $DISK não existe ou não é um dispositivo de bloco."
      continue
    fi

    if ! lsblk -no TYPE "$DISK" | grep -q '^disk$'; then
      echo " :: Erro: $DISK não parece ser um disco inteiro (é partição?)."
      continue
    fi

    echo ""
    echo " :: Disco selecionado: $DISK"
    lsblk -f "$DISK"
    echo ""

    read -r -p "CONFIRMA? (todo o conteúdo será APAGADO) [S/N]: " confirma

    confirma=$(echo "$confirma" | tr '[:upper:]' '[:lower:]')
    if [[ "$confirma" == "s" || "$confirma" == "sim" ]]; then
      break
    else
      echo " :: Abortado. Escolha outro disco."
    fi
  done

  if [[ -z "$DISK" ]]; then
    echo " :: Nenhum disco selecionado! Abortando..."
    exit 1
  fi

  echo " :: TODOS OS DADOS EM $DISK SERÃO APAGADOS!"

  wipefs -a "$DISK"
  sfdisk "$DISK" <<EOF
label: gpt
size=8G, type=swap, name=swap
size=600M, type=uefi, name=EFI
type=linux, name=arch-root
EOF

  # Aguarda o kernel re-ler a tabela de partições
  sleep 2

  if [[ "$DISK" =~ nvme || "$DISK" =~ mmcblk ]]; then
    PART="${DISK}p"
  else
    PART="${DISK}"
  fi
  SWAP="${PART}1"
  EFI="${PART}2"
  ROOT="${PART}3"

  mkswap -L swap "$SWAP" && swapon "$SWAP"
  mkfs.fat -F32 -n EFI "$EFI"
  mkfs.btrfs -f -L ArchRoot "$ROOT"

  mount "$ROOT" /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@cache
  btrfs subvolume create /mnt/@log
  btrfs subvolume create /mnt/@.snapshots
  umount /mnt

  OPTS_GERAL="noatime,compress=zstd:3,space_cache=v2,discard=async,autodefrag,ssd,commit=30"

  mount -o $OPTS_GERAL,subvol=@ "$ROOT" /mnt
  mkdir -p /mnt/{boot/efi,home,.snapshots,var/{cache,log}}

  mount -o $OPTS_GERAL,subvol=@home "$ROOT" /mnt/home
  mount -o $OPTS_GERAL,subvol=@cache "$ROOT" /mnt/var/cache
  mount -o $OPTS_GERAL,subvol=@log "$ROOT" /mnt/var/log
  mount -o $OPTS_GERAL,subvol=@.snapshots "$ROOT" /mnt/.snapshots

  mount "$EFI" /mnt/boot/efi

  lsblk
  echo " :: Continuando em 5 segundos..."
  sleep 5

  pacstrap -K /mnt \
    base base-devel linux-zen linux-zen-headers linux-firmware \
    amd-ucode btrfs-progs openssh nano git ufw

  echo ""
  echo " :: Gerando fstab"
  genfstab -U /mnt >> /mnt/etc/fstab
  sleep 10

  echo ""
  echo ""
  cp "$0" /mnt/root/install-arch-linux.sh
  chmod +x /mnt/root/install-arch-linux.sh

  echo " :: Entrando no chroot... O script vai continuar sozinho :)"
  arch-chroot /mnt /root/install-arch-linux.sh

  echo " :: Instalação base concluída. Reinicie e remova o pendrive."
  umount -R /mnt
  reboot
  exit 0

fi

#------------------------------------------------------------------------------#
#                               PARTE 2 - CHROOT                               #
#------------------------------------------------------------------------------#
if (( IN_CHROOT == 1 )); then

  echo " :: Setando o TimeZone e configurando localidade"
  ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
  hwclock --systohc
  timedatectl set-ntp true

  sed -i "s/^#$LOCALE_FALLBACK/$LOCALE_FALLBACK/" /etc/locale.gen
  sed -i "s/^#$LOCALE/$LOCALE/" /etc/locale.gen
  locale-gen

  echo "LANG=$LOCALE" >> /etc/locale.conf
  echo "KEYMAP=$KEYMAP" >> /etc/vconsole.conf
  export LANG="$LOCALE"

  echo "$HOSTNAME" >> /etc/hostname
  cat > /etc/hosts <<EOF
127.0.0.1    localhost
::1          localhost
127.0.1.1    $HOSTNAME.localdomain    $HOSTNAME
EOF

  echo " :: Configurando arquivo pacman.conf"
  sed -i "s/^#Color/Color/" /etc/pacman.conf
  sed -i "s/.*ParallelDownloads.*/ParallelDownloads = 10/" /etc/pacman.conf
  sed -i "/\[multilib\]/,/Include/ s/^#//" /etc/pacman.conf

  echo " :: Habilitando grupo wheel"
  sed -i "s/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers
  grep wheel /etc/sudoers

  echo " :: Configurando Usuário e Senha"
  echo "root:$ROOT_PASSWORD" | chpasswd
  useradd -mG wheel "$USERNAME"
  usermod -aG storage,power,audio "$USERNAME"
  echo "$USERNAME:$USER_PASSWORD" | chpasswd

  echo " :: Instalando pacotes básicos para reinicialização"
  pacman -Syy --noconfirm dosfstools networkmanager grub efibootmgr go

  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ArchLinux --recheck
  grub-mkconfig -o /boot/grub/grub.cfg

  systemctl enable NetworkManager
  systemctl enable ufw
  ufw --force enable
  systemctl enable fstrim.timer

  echo " :: Instalando Paru (AUR Helper)"
  sudo -u "$USERNAME" git clone https://aur.archlinux.org/paru.git /tmp/paru
  cd /tmp/paru
  sudo -u "$USERNAME" makepkg -c
  pacman -U --noconfirm paru-*.pkg.tar.zst
  rm -rf /tmp/paru

  rm -f /root/install-arch-linux.sh

  echo ""
  echo "============================================================"
  echo "  Fase base concluída!"
  echo "  Reinicie, logue como '$USERNAME'"
  echo ""
  echo "============================================================"
  exit 0

fi
