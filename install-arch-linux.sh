#!/usr/bin/env bash
#
# Script de Instalação — Arch Linux + BTRFS
# Hardware: Ryzen 5 3600 · RTX 2060 · NVMe 1TB · 16GB RAM
#
# Executa Parte 1 (live) -> chroot -> Parte 2 automaticamente
# Depois: logar como usuário e rodar script "post-install.sh"
#

set -euo pipefail

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║             INSTALAÇÃO DO ARCH LINUX + BTRFS             ║"
echo "  ║       Ryzen 5 3600 · RTX 2060 · NVMe 1TB · 16GB RAM      ║"
echo "  ║                                                          ║"
echo "  ║   Pt.01 - INSTALAÇÃO DA BASE                             ║"
echo "  ║   Pt.02 - CONFIGURAÇÕES PRÉ REINICIALIZAÇÃO              ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

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
USER_PASSWORD=""
ROOT_PASSWORD=""

#------------------------------------------------------------------------------#
#                              FUNÇÕES AUXILIARES                              #
#------------------------------------------------------------------------------#
prompt_password() {
  local label="$1" varname="$2" pass1 pass2
  while true; do
    read -rs -p "  Senha para $label: " pass1; echo
    read -rs -p "  Confirme a senha para $label: " pass2; echo
    if [[ -z "$pass1" ]]; then
      echo -e "  ${RED}[ERRO] A senha não pode ser vazia.${NC}"
      continue
    fi
    if [[ "$pass1" != "$pass2" ]]; then
      echo -e "  ${RED}[ERRO] As senhas não coincidem. Tente novamente.${NC}"
      continue
    fi
    printf -v "$varname" '%s' "$pass1"
    break
  done
}

#------------------------------------------------------------------------------#
#                              DETECTAR AMBIENTE                               #
#------------------------------------------------------------------------------#
if systemd-detect-virt --chroot >/dev/null 2>&1; then
  echo -e "${GREEN}:: [DETECT] Modo CHROOT detectado.${NC}"
  echo ""
  IN_CHROOT=1
else
  echo -e "${GREEN}:: [DETECT] Modo LIVE USB detectado.${NC}"
  echo ""
  IN_CHROOT=0
fi

#------------------------------------------------------------------------------#
#                              PARTE 1 - LIVE USB                              #
#------------------------------------------------------------------------------#
if (( IN_CHROOT == 0 )); then

  echo -e "${CYAN}:: [1/9] Verificando ambiente UEFI...${NC}"
  if [[ ! -d /sys/firmware/efi ]]; then
    echo -e ""
    echo -e "${RED}[ERRO] Sistema não foi inicializado em modo UEFI.${NC}"
    echo -e "${YELLOW}:: Este script requer UEFI. Reinicie e selecione UEFI na BIOS.${NC}"
    echo ""
    exit 1
  fi
  echo -e "${GREEN}:: [OK] Modo UEFI confirmado.${NC}"
  echo ""

  echo -e "${CYAN}:: [2/9] Configurando teclado e relógio...${NC}"
  loadkeys "$KEYMAP"
  timedatectl set-ntp true
  echo -e "${GREEN}:: [OK] Teclado ($KEYMAP) e NTP configurados.${NC}"
  echo ""

  echo -e "${CYAN}:: [3/9] Verificando conexão com a internet...${NC}"
  ping -c 4 archlinux.org >/dev/null || {
    echo -e "${RED}[ERRO] Sem conexão com a internet.${NC}"
    exit 1
  }
  echo -e "${GREEN}:: [OK] Conexão com a internet estabelecida.${NC}"
  echo ""

  echo -e "${CYAN}:: [4/9] Sincronizando repositórios...${NC}"
  if command -v reflector &>/dev/null; then
    echo -e "${YELLOW}:: Otimizando mirrorlist com reflector (Brasil)...${NC}"
    reflector --country Brazil --age 12 --protocol https --sort rate \
      --save /etc/pacman.d/mirrorlist
  fi
  pacman -Syy --noconfirm
  echo -e "${GREEN}:: [OK] Repositórios sincronizados.${NC}"
  echo ""

  echo -e "${CYAN}:: [5/9] Selecionando disco de instalação...${NC}"
  echo ""
  echo -e "${YELLOW}:: Discos disponíveis:${NC}"
  echo "  -------------------  "
  lsblk -d -o NAME,SIZE,TYPE,MODEL | grep -v '^NAME' | grep disk
  echo ""

  while true; do
    read -r -p "  Digite o disco alvo (ex: /dev/nvme0n1 ou /dev/sda): " DISK_INPUT

    DISK="/dev/${DISK_INPUT##*/}"
    if [[ ! -b "$DISK" ]]; then
      echo -e "  ${RED}[ERRO] $DISK não existe ou não é um dispositivo de bloco.${NC}"
      continue
    fi

    if ! lsblk -no TYPE "$DISK" | grep -q '^disk$'; then
      echo -e "  ${RED}[ERRO] $DISK não parece ser um disco inteiro (é partição?).${NC}"
      continue
    fi

    echo ""
    echo -e "  ${YELLOW}:: Disco selecionado: $DISK${NC}"
    lsblk -f "$DISK"
    echo ""

    read -r -p "  CONFIRMA? (todo o conteúdo será APAGADO) [S/N]: " confirma

    confirma=$(echo "$confirma" | tr '[:upper:]' '[:lower:]')
    if [[ "$confirma" == "s" || "$confirma" == "sim" ]]; then
      break
    else
      echo -e "  ${YELLOW}:: Abortado. Escolha outro disco.${NC}"
    fi
  done

  if [[ -z "$DISK" ]]; then
    echo -e "${RED}[ERRO] Nenhum disco selecionado! Abortando...${NC}"
    exit 1
  fi

  echo -e "${RED}:: ATENÇÃO: TODOS OS DADOS EM $DISK SERÃO APAGADOS!${NC}"
  echo ""

  echo -e "${CYAN}:: [6/9] Definindo credenciais de acesso...${NC}"
  prompt_password "root" ROOT_PASSWORD
  prompt_password "usuário ($USERNAME)" USER_PASSWORD
  echo -e "${GREEN}:: [OK] Credenciais definidas.${NC}"
  echo ""

  echo -e "${CYAN}:: [7/9] Particionando, formatando e montando o disco...${NC}"
  echo -e "${YELLOW}:: Apagando assinaturas de sistema de arquivos...${NC}"
  wipefs -a "$DISK"

  echo -e "${YELLOW}:: Criando tabela de partições (GPT: swap + EFI + root)...${NC}"
  sfdisk "$DISK" <<EOF
label: gpt
size=8G, type=swap, name=swap
size=600M, type=uefi, name=EFI
type=linux, name=arch-root
EOF

  # Exceção intencional: partprobe pode retornar erro mesmo quando a tabela
  # já foi relida (falso-negativo comum). Mantido não-fatal porque, se a
  # partição realmente não existir, mkswap/mkfs.fat/mkfs.btrfs abaixo vão
  # falhar de forma explícita mesmo assim.
  partprobe "$DISK" || true
  udevadm settle
  sleep 1

  if [[ "$DISK" =~ nvme || "$DISK" =~ mmcblk ]]; then
    PART="${DISK}p"
  else
    PART="${DISK}"
  fi
  SWAP="${PART}1"
  EFI="${PART}2"
  ROOT="${PART}3"

  echo -e "${YELLOW}:: Formatando partições...${NC}"
  mkswap -L swap "$SWAP" && swapon "$SWAP"
  mkfs.fat -F32 -n EFI "$EFI"
  mkfs.btrfs -f -L ArchRoot "$ROOT"

  echo -e "${YELLOW}:: Criando subvolumes BTRFS...${NC}"
  mount "$ROOT" /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@cache
  btrfs subvolume create /mnt/@log
  btrfs subvolume create /mnt/@.snapshots
  umount /mnt

  OPTS_GERAL="noatime,compress=zstd:3,space_cache=v2,discard=async,ssd,commit=30"

  echo -e "${YELLOW}:: Montando subvolumes...${NC}"
  mount -o $OPTS_GERAL,subvol=@ "$ROOT" /mnt
  mkdir -p /mnt/{boot/efi,home,.snapshots,var/{cache,log}}

  mount -o $OPTS_GERAL,subvol=@home "$ROOT" /mnt/home
  mount -o $OPTS_GERAL,subvol=@cache "$ROOT" /mnt/var/cache
  mount -o $OPTS_GERAL,subvol=@log "$ROOT" /mnt/var/log
  mount -o $OPTS_GERAL,subvol=@.snapshots "$ROOT" /mnt/.snapshots

  mount "$EFI" /mnt/boot/efi

  echo -e "${GREEN}:: Partições montadas:${NC}"
  lsblk
  echo -e "${YELLOW}:: Continuando em 5 segundos...${NC}"
  sleep 5

  echo -e "${CYAN}:: [8/9] Instalando pacotes base (pacstrap)...${NC}"
  pacstrap -K /mnt \
    base base-devel sudo \
    linux-zen linux-zen-headers linux-firmware \
    amd-ucode btrfs-progs exfatprogs \
    nano openssh git cargo

  echo ""
  echo -e "${CYAN}:: [9/9] Gerando fstab e preparando chroot...${NC}"
  echo -e "${YELLOW}:: Gerando fstab...${NC}"
  genfstab -U /mnt >> /mnt/etc/fstab
  sleep 10

  echo ""
  echo -e "${YELLOW}:: Gravando credenciais temporárias para o chroot...${NC}"
  cat > /mnt/root/.chroot-creds <<CREDS
ROOT_PASSWORD='$ROOT_PASSWORD'
USER_PASSWORD='$USER_PASSWORD'
CREDS
  chmod 600 /mnt/root/.chroot-creds

  echo -e "${YELLOW}:: Copiando script para o ambiente chroot...${NC}"
  cp "$0" /mnt/root/install-arch-linux.sh
  chmod +x /mnt/root/install-arch-linux.sh

  echo -e "${GREEN}:: Entrando no chroot... O script vai continuar sozinho :)${NC}"
  arch-chroot /mnt /root/install-arch-linux.sh

  echo -e "${GREEN}"
  echo "  ╔══════════════════════════════════════════════════════════╗"
  echo "  ║   Instalação base concluída!                             ║"
  echo "  ║   Remova o pendrive e reinicie o sistema.                ║"
  echo "  ╚══════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  umount -R /mnt
  sleep 3
  reboot
  exit 0

fi

#------------------------------------------------------------------------------#
#                               PARTE 2 - CHROOT                               #
#------------------------------------------------------------------------------#
if (( IN_CHROOT == 1 )); then

  echo -e "${CYAN}:: [1/7] Configurando TimeZone e localidade...${NC}"
  ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
  hwclock --systohc
  timedatectl set-ntp true || true

  sed -i "s/^#$LOCALE_FALLBACK/$LOCALE_FALLBACK/" /etc/locale.gen
  sed -i "s/^#$LOCALE/$LOCALE/" /etc/locale.gen
  locale-gen

  echo "LANG=$LOCALE" > /etc/locale.conf
  echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
  export LANG="$LOCALE"
  echo -e "${GREEN}:: [OK] TimeZone e localidade configurados.${NC}"
  echo ""

  echo -e "${CYAN}:: [2/7] Configurando hostname e hosts...${NC}"
  echo "$HOSTNAME" > /etc/hostname
  cat > /etc/hosts <<EOF
127.0.0.1    localhost
::1          localhost
127.0.1.1    $HOSTNAME.localdomain    $HOSTNAME
EOF
  echo -e "${GREEN}:: [OK] Hostname definido como '$HOSTNAME'.${NC}"
  echo ""

  echo -e "${CYAN}:: [3/7] Configurando pacman.conf (cores, parallel downloads, multilib)...${NC}"
  sed -i "s/^#Color/Color/" /etc/pacman.conf
  sed -i "s/.*ParallelDownloads.*/ParallelDownloads = 10/" /etc/pacman.conf
  sed -i "/\[multilib\]/,/Include/ s/^#//" /etc/pacman.conf
  echo -e "${GREEN}:: [OK] pacman.conf configurado.${NC}"
  echo ""

  echo -e "${CYAN}:: [4/7] Habilitando grupo wheel no sudoers...${NC}"
  sed -i "s/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers
  grep wheel /etc/sudoers
  echo -e "${GREEN}:: [OK] Grupo wheel habilitado.${NC}"
  echo ""

  echo -e "${CYAN}:: [5/7] Configurando usuário e senhas...${NC}"
  if [[ ! -f /root/.chroot-creds ]]; then
    echo -e "${RED}[ERRO] Arquivo de credenciais não encontrado em /root/.chroot-creds.${NC}"
    exit 1
  fi

  source /root/.chroot-creds
  rm -f /root/.chroot-creds

  echo "root:$ROOT_PASSWORD" | chpasswd
  useradd -mG wheel "$USERNAME"
  usermod -aG storage,power,audio "$USERNAME"

  echo "$USERNAME:$USER_PASSWORD" | chpasswd
  unset ROOT_PASSWORD USER_PASSWORD
  echo -e "${GREEN}:: [OK] Usuário '$USERNAME' criado e configurado.${NC}"
  echo ""

  echo -e "${CYAN}:: [6/7] Instalando pacotes essenciais e configurando boot...${NC}"
  echo -e "${YELLOW}:: Instalando GRUB, NetworkManager e dependências...${NC}"
  pacman -Syy --noconfirm \
    dosfstools networkmanager ufw \
    grub efibootmgr \
    go irqbalance

  echo ""
  echo -e "${YELLOW}:: Instalando GRUB na partição EFI...${NC}"
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ArchLinux --recheck
  grub-mkconfig -o /boot/grub/grub.cfg

  echo ""
  echo -e "${YELLOW}:: Habilitando serviços de sistema...${NC}"

  systemctl enable NetworkManager
  systemctl enable ufw
  ufw --force enable
  systemctl enable fstrim.timer

  echo -e "${GREEN}:: [OK] Boot e serviços configurados.${NC}"
  echo ""

  echo -e "${CYAN}:: [7/7] Instalando Paru (AUR Helper)...${NC}"
  sudo -u "$USERNAME" git clone https://aur.archlinux.org/paru.git /tmp/paru
  cd /tmp/paru
  sudo -u "$USERNAME" makepkg -sc --noconfirm
  pacman -U --noconfirm paru-*.pkg.tar.zst
  cd /tmp
  rm -rf /tmp/paru

  rm -f /root/install-arch-linux.sh

  echo -e "${GREEN}"
  echo "  ╔══════════════════════════════════════════════════════════╗"
  echo "  ║   Fase base concluída com sucesso!                       ║"
  echo "  ║                                                          ║"
  echo "  ║   Reinicie, logue como '$USERNAME'                          ║"
  echo "  ║   e execute: ./post-install.sh                           ║"
  echo "  ╚══════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  exit 0

fi
