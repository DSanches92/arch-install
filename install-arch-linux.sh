#!/usr/bin/env bash
#
# Instalação Arch + BTRFS = Hyprland (AMD + NVIDIA Open)
# Executa Parte 1 (live) -> chroot -> Parte 2 automaticamente
# Depois: logar como usuário e rodar script "install-hyprland.sh" separado
#

set -euo pipefail

#------------------------------------------------------------------------------#
#                            CONFIGURAÇÕES INICIAIS                            #
#------------------------------------------------------------------------------#

DISK=""
HOSTNAME="dsanches"
USERNAME="danilo"
TIMEZONE="America/Sao_Paulo"
LOCALE="pt_BR.UTF-8"
KEYMAP="br-abnt2"
USER_PASSWORD="12345"
ROOT_PASSWORD="12345"

#------------------------------------------------------------------------------#
#                              DETECTAR AMBIENTE                               #
#------------------------------------------------------------------------------#
if systemd-detect-virt --chroot >/dev/null 2>&1; then
  echo "=== MODO CHROOT ==="
  IN_CHROOT=1
else
  echo "=== MODO LIVE USB ==="
  IN_CHROOT=0
fi

#------------------------------------------------------------------------------#
#                              PARTE 1 - LIVE USB                              #
#------------------------------------------------------------------------------#
if (( IN_CHROOT == 0 )); then

  loadkeys "$KEYMAP"
  setfont ter-132b
  timedatectl set-ntp true

  ping -c 4 archlinux.org >/dev/null || { echo " :: Sem internet"; exit 1; }

  echo " :: Otimizando lista de mirrors para o Brasil..."

  pacman -Sy --noconfirm reflector || true
  reflector --verbose \
    --latest 10 \
    --protocol https \
    --sort rate \
    --country Brazil,UnitedStates \
    --save /etc/pacman.d/mirrorlist

  echo " :: Mirrorlist atualizado:"
  cat /etc/pacman.d/mirrorlist | grep -v '^#' | head -n 10
  echo " :: ... (mostrando apenas os primeiros 10)"

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
    if [[ "$confirma" == "s" || "$confirma" == "sim" || "$confirma" == "y" || "$confirma" == "yes" ]]; then
      break
    else
      echo " :: Abortado. Escolha outro disco."
    fi
  done

  if [[ -z "$DISK"]]; then
    echo " :: Nenhum disco selecionado! Abortando..."
    exit 1
  fi

  echo " :: Disco selecionado: $DISK"
  lsblk -f
  echo " :: TODOS OS DADOS EM $DISK SERÃO APAGADOS!"
  read -p "Seguir com a formatação do disco selecionado? [Y/n]" confirma

  confirma=$(echo "$confirma" | tr '[:upper:]' '[:lower:]')
  [[ "$confirma" != "y" || "$confirma" != "s" || "$confirma" != "" ]]; && exit 1

  sfdisk "$DISK" <<EOF
label: gpt
size=8G, type=82, name=swap
size=600M, type=EF00, name=EFI
type=8300, name=arch-root
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

  pacstrap -K /mnt \
    base base-devel linux linux-headers linux-firmware power-profiles-daemon \
    amd-ucode btrfs-progs openssh nano ntp git
  
  genfstab -U /mnt >> /mnt/etc/fstab

  cp "$0" /mnt/root/install-arch-linux.sh
  chmod +x /mnt/root/install-arch-linux.sh

  echo " :: Entrando no chroot... O script vai continuar sozinho"
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

  ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
  hwclock --systohc
  ntpdate a.ntp.br
  hwclock -w

  sed -i "/en_US.UTF-8/s/^/#/" /etc/locale.gen
  sed -i "/$LOCALE/s/#//" /etc/locale.gen
  locale-gen
  echo "LANG=$LOCALE" >> /etc/locale.conf
  echo "KEYMAP=$KEYMAP" >> /etc/vconsole.conf
  export LANG="$LOCALE"

  echo "$HOSTNAME" >> /etc/hostname
  cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF

  sed -i "s/^#Color/Color/" /etc/pacman.conf
  sed -i "s/.*ParallelDownloads.*/ParallelDownloads = 10" /etc/pacman.conf
  sed -i "/\[multilib\]/,/Include/ s/^#//" /etc/pacman.conf

  # Habilita grupo wheel
  sed -i "s/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers.d/wheel
  grep wheel /etc/sudoers

  # Usuários e senhas
  echo "root:$ROOT_PASSWORD" | chpasswd
  useradd -mG wheel "$USERNAME"
  usermod -aG storage,power,audio "$USERNAME"
  echo "$USERNAME:$USER_PASSWORD" | chpasswd

  pacman -Syy --noconfirm \
    dosfstools mtools networkmanager grub-efi-x86_64 efibootmgr \
    ufw fastfetch steam gamemode lib32-gamemode

  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ArchLinux --recheck
  grub-mkconfig -o /boot/grub/grub.cfg

  ufw enable

  systemctl enable NetworkManager ufw

  usermod -aG gamemode "$USERNAME"

  rm -f /root/install-arch-linux.sh

  echo ""
  echo "============================================================"
  echo "  Fase base concluída!"
  echo "  Reinicie, logue como $USERNAME e execute:"
  echo "  sudo pacman -Syyuu"
  echo ""
  echo "  Execute também:"
  echo "  gamemoded -t"
  echo "  Depois rode o script install-hyprland.sh (copie ele antes)"
  echo "============================================================"
  exit 0

fi
