#!/usr/bin/env bash
#
# Instalação Arch + BTRFS
# Executa Parte 1 (live) -> chroot -> Parte 2 automaticamente
# Depois: logar como usuário e rodar script "install-hyprland.sh" separado
#

set -euo pipefail

echo "                             ###                ###       ## "
echo "                              ##                 ## "
echo "   ####    ######    ####     ##                 ##      ###     #####    ##  ##   ##  ## "
echo "      ##    ##  ##  ##  ##    #####              ##       ##     ##  ##   ##  ##    #### "
echo "   #####    ##      ##        ##  ##             ##       ##     ##  ##   ##  ##     ## "
echo "  ##  ##    ##      ##  ##    ##  ##             ##       ##     ##  ##   ##  ##    #### "
echo "   #####   ####      ####    ###  ##            ####     ####    ##  ##    ######  ##  ## "
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

  echo " :: Disco selecionado: $DISK"
  lsblk -f
  echo " :: TODOS OS DADOS EM $DISK SERÃO APAGADOS!"
  read -p "Seguir com a formatação do disco selecionado? [S/N]: " confirma

  confirma=$(echo "$confirma" | tr '[:upper:]' '[:lower:]')
  if ! [[ "$confirma" == "s" || "$confirma" == "sim" ]]; then
    exit 1
  fi

  wipefs -a "$DISK"
  sfdisk "$DISK" <<EOF
label: gpt
size=8G, type=swap, name=swap
size=600M, type=uefi, name=EFI
type=linux, name=arch-root
EOF

  SWAP="${DISK}p1"
  EFI="${DISK}p2"
  ROOT="${DISK}p3"

  mkswap -L swap "$SWAP" && swapon "$SWAP"
  mkfs.fat -F32 -n EFI "$EFI"
  mkfs.btrfs -f -L ArchRoot "$ROOT"

  mount "$ROOT" /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@cache
  btrfs subvolume create /mnt/@log
  umount /mnt

  OPTS_GERAL="noatime,compress=zstd:3,space_cache=v2,discard=async,autodefrag,ssd,commit=120"

  mount -o $OPTS_GERAL,subvol=@ "$ROOT" /mnt
  mkdir -p /mnt/{boot/efi,home,var/{cache,log}}

  mount -o $OPTS_GERAL,subvol=@home "$ROOT" /mnt/home
  mount -o $OPTS_GERAL,subvol=@cache "$ROOT" /mnt/var/cache
  mount -o $OPTS_GERAL,subvol=@log "$ROOT" /mnt/var/log
  
  mount "$EFI" /mnt/boot/efi

  lsblk
  echo " :: Continuando em 5 segundos..."
  sleep 5

  pacstrap -K /mnt \
    base base-devel linux linux-headers linux-firmware power-profiles-daemon \
    amd-ucode btrfs-progs openssh nano ntp git ufw
  
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
  ntpdate a.ntp.br
  hwclock -w

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
  pacman -Syy --noconfirm dosfstools mtools networkmanager grub efibootmgr

  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ArchLinux --recheck
  grub-mkconfig -o /boot/grub/grub.cfg

  systemctl enable NetworkManager

  rm -f /root/install-arch-linux.sh

  echo ""
  echo "============================================================"
  echo "  Fase base concluída!"
  echo "  Reinicie, logue como '$USERNAME'"
  echo ""
  echo "  Rode o script install-hyprland.sh (copie ele antes)"
  echo "============================================================"
  exit 0

fi
