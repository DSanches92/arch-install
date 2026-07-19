#!/usr/bin/env bash
#
# Script de Pós-Instalação — Arch Linux + BTRFS
# Hardware: Ryzen 5 3600 · RTX 2060 · NVMe 1TB · 16GB RAM
# Kernel: linux-zen
#
# Uso: chmod +x post-install.sh && ./post-install.sh
#
# Este script NÃO deve ser executado dentro do arch-chroot.
# Execute APÓS o primeiro boot, logado como usuário normal.
#

set -euo pipefail

# Cores para saída do terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

#------------------------------------------------------------------------------#
#                    CONFIGURAÇÕES — AJUSTE SE NECESSÁRIO                      #
#------------------------------------------------------------------------------#

USERNAME="danilo"
GRUB_FILE="/etc/default/grub"
MKINITCPIO_FILE="/etc/mkinitcpio.conf"
NVIDIA_MODULES="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
GRUB_PARAMS="nvidia-drm.modeset=1 nvidia-drm.fbdev=1"

#------------------------------------------------------------------------------#
#                         VERIFICAÇÃO DE PRIVILÉGIOS                           #
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: Verificando privilégios sudo...${NC}"
if ! sudo -v &>/dev/null; then
  echo -e "${RED}[ERRO] Este script requer privilégios sudo.${NC}"
  echo -e "${YELLOW}:: Execute como usuário com permissão sudo (membro do grupo wheel).${NC}"
  exit 1
fi
echo -e "${GREEN}:: [OK] Privilégios sudo confirmados.${NC}"
echo ""

# Mantém o sudo vivo enquanto o script roda
while true; do sudo -v; sleep 60; done &
SUDO_PID=$!
trap 'kill $SUDO_PID 2>/dev/null' EXIT

echo -e "${BLUE}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║       PÓS-INSTALAÇÃO ARCH + BTRFS                    ║"
echo "  ║   Ryzen 5 3600 · RTX 2060 · NVMe · 16GB              ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

#------------------------------------------------------------------------------#
#                   1. SINCRONIZAÇÃO E ATUALIZAÇÃO COMPLETA                    #
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [1/5] Sincronizando repositórios e atualizando o sistema...${NC}"
echo ""

paru -Syyuu --noconfirm

echo ""
echo -e "${YELLOW}:: Instalando Python (necessário para scripts auxiliares)...${NC}"
sudo pacman -S --needed --noconfirm python

echo ""
echo -e "${GREEN}:: [1/5] Concluído.${NC}"
echo ""

#------------------------------------------------------------------------------#
#                   2. DRIVERS NVIDIA (RTX 2060 - TURING)                      #
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [2/5] Instalando drivers NVIDIA (RTX 2060 / Turing)...${NC}"
echo ""

# DKMS: compila o módulo aberto (Turing+) contra o linux-zen instalado
sudo pacman -S --needed --noconfirm \
  nvidia-open-dkms \
  nvidia-utils \
  lib32-nvidia-utils \
  nvidia-settings \
  libva-nvidia-driver

echo ""
echo -e "${YELLOW}:: Configurando parâmetros no GRUB...${NC}"
echo ""

if [[ -f "$GRUB_FILE" ]]; then
  sudo cp "$GRUB_FILE" "$GRUB_FILE.bak-$(date +%Y%m%d-%H%M%S)"

  CURRENT_LINE=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_FILE" | head -n1)

  if [[ -z "$CURRENT_LINE" ]]; then
    echo -e "${RED}[ERRO] GRUB_CMDLINE_LINUX_DEFAULT não encontrado.${NC}"
    exit 1
  fi

  CURRENT_PARAMS=$(echo "$CURRENT_LINE" | sed -n 's/.*GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)".*/\1/p')

  if ! echo "$CURRENT_PARAMS" | grep -q "$GRUB_PARAMS"; then
    NEW_PARAMS="$CURRENT_PARAMS $GRUB_PARAMS"
    NEW_PARAMS=$(echo "$NEW_PARAMS" | xargs)
    sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$NEW_PARAMS\"|" "$GRUB_FILE"
    echo -e "${GREEN}:: GRUB atualizado: $NEW_PARAMS${NC}"
  else
    echo -e "${YELLOW}:: Parâmetros já presentes. Pulando.${NC}"
  fi
else
  echo -e "${RED}[ERRO] $GRUB_FILE não encontrado.${NC}"
  exit 1
fi

echo ""
echo -e "${YELLOW}:: Configurando módulos NVIDIA no mkinitcpio...${NC}"
echo ""

if [[ -f "$MKINITCPIO_FILE" ]]; then
  sudo cp "$MKINITCPIO_FILE" "$MKINITCPIO_FILE.bak-$(date +%Y%m%d-%H%M%S)"

  CURRENT_MODULES=$(grep "^MODULES=" "$MKINITCPIO_FILE" | sed -n 's/.*MODULES=\((.*)\).*/\1/p' | tr -d '()')
  for mod in $NVIDIA_MODULES; do
    if ! echo "$CURRENT_MODULES" | grep -qw "$mod"; then
      CURRENT_MODULES="$CURRENT_MODULES $mod"
    fi
  done
  NEW_MODULES=$(echo "$CURRENT_MODULES" | xargs)
  sudo sed -i "s|^MODULES=.*|MODULES=($NEW_MODULES)|" "$MKINITCPIO_FILE"
  echo -e "${GREEN}:: MODULES atualizado: ($NEW_MODULES)${NC}"

  CURRENT_HOOKS=$(grep "^HOOKS=" "$MKINITCPIO_FILE" | sed -n 's/.*HOOKS=\((.*)\).*/\1/p' | tr -d '()')
  NEW_HOOKS=$(echo "$CURRENT_HOOKS" | sed 's/kms//g' | xargs)
  if [[ "$NEW_HOOKS" != "$CURRENT_HOOKS" ]]; then
    sudo sed -i "s|^HOOKS=.*|HOOKS=($NEW_HOOKS)|" "$MKINITCPIO_FILE"
    echo -e "${GREEN}:: 'kms' removido dos HOOKS.${NC}"
  else
    echo -e "${YELLOW}:: 'kms' ausente nos HOOKS. Nada a remover.${NC}"
  fi
else
  echo -e "${RED}[ERRO] $MKINITCPIO_FILE não encontrado.${NC}"
  exit 1
fi

echo ""
echo -e "${YELLOW}:: Reconstruindo initramfs...${NC}"
sudo mkinitcpio -P

echo ""
echo -e "${GREEN}:: [2/5] Concluído.${NC}"
echo ""

#------------------------------------------------------------------------------#
#                   3. ÁUDIO (PIPEWIRE + WIREPLUMBER)                         #
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [3/5] Instalando PipeWire, WirePlumber e codecs...${NC}"
echo ""

sudo pacman -S --needed --noconfirm \
  pipewire \
  pipewire-alsa \
  pipewire-jack \
  pipewire-pulse \
  wireplumber \
  gstreamer \
  gst-libav \
  gst-plugins-base \
  gst-plugins-good \
  gst-plugins-bad \
  gst-plugins-ugly \
  ffmpeg \
  ffmpegthumbnailer \
  libdvdcss \
  libva-mesa-driver \
  mesa-utils \
  vulkan-icd-loader \
  lib32-mesa-utils \
  lib32-vulkan-icd-loader

# Instala codecs AUR via paru
echo -e "${YELLOW}:: Instalando codecs de áudio/vídeo do AUR...${NC}"
paru -S --needed --noconfirm \
  a52dec \
  faac \
  faad2 \
  flac \
  lame \
  x264 \
  x265 \
  xvidcore \
  pavucontrol

echo ""
echo -e "${YELLOW}:: Ativando serviços de áudio (usuário)...${NC}"
systemctl --user enable pipewire pipewire-pulse wireplumber 2>/dev/null || true

echo ""
echo -e "${GREEN}:: [3/5] Concluído.${NC}"
echo ""

#------------------------------------------------------------------------------#
#                   4. OTIMIZAÇÕES DE DESEMPENHO                               #
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [4/5] Aplicando otimizações de desempenho...${NC}"
echo ""

# --- Swappiness: reduz uso de swap (16GB RAM, uso apenas emergencial) ---
echo -e "${YELLOW}:: Ajustando swappiness para 10...${NC}"
echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-swappiness.conf >/dev/null

# --- Cache de inode/dentry: mantém por mais tempo ---
echo -e "${YELLOW}:: Ajustando vfs_cache_pressure para 50...${NC}"
echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.d/99-swappiness.conf >/dev/null

# --- Agendador de E/S: kyber ou none para NVMe ---
echo -e "${YELLOW}:: Configurando agendador de I/O para NVMe...${NC}"
for DEV in /sys/block/nvme*/queue/scheduler; do
  if [[ -w "$DEV" ]]; then
    echo "none" | sudo tee "$DEV" >/dev/null
  fi
done

# --- Persiste agendador via udev ---
echo 'ACTION=="add|change", KERNEL=="nvme*", ATTR{queue/scheduler}="none"' | \
  sudo tee /etc/udev/rules.d/60-iosched-nvme.rules >/dev/null

# --- irqbalance: distribui interrupções entre CPUs ---
echo -e "${YELLOW}:: Ativando irqbalance...${NC}"
sudo systemctl enable --now irqbalance 2>/dev/null || true

# --- fstrim: já habilitado no instalador base, mas garantimos ---
echo -e "${YELLOW}:: Verificando fstrim.timer...${NC}"
sudo systemctl enable --now fstrim.timer 2>/dev/null || true

# --- AMD P-state driver (Ryzen 5 3600) ---
echo -e "${YELLOW}:: Habilitando AMD P-State na linha de comando do kernel...${NC}"
if ! grep -q "amd_pstate=active" "$GRUB_FILE" 2>/dev/null; then
  CURRENT_LINE=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_FILE" | head -n1)
  CURRENT_PARAMS=$(echo "$CURRENT_LINE" | sed -n 's/.*GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)".*/\1/p')
  NEW_PARAMS="$CURRENT_PARAMS amd_pstate=active"
  NEW_PARAMS=$(echo "$NEW_PARAMS" | xargs)
  sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$NEW_PARAMS\"|" "$GRUB_FILE"
  echo -e "${GREEN}:: amd_pstate=active adicionado ao GRUB.${NC}"
else
  echo -e "${YELLOW}:: amd_pstate=active já presente. Pulando.${NC}"
fi

sudo grub-mkconfig -o /boot/grub/grub.cfg

echo ""
echo -e "${GREEN}:: [4/5] Concluído.${NC}"
echo ""

#------------------------------------------------------------------------------#
#                   5. LIMPEZA E VERIFICAÇÃO FINAL                             #
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [5/5] Limpeza e verificação final...${NC}"
echo ""

# Limpa cache do pacman (mantém apenas as 3 versões mais recentes)
echo -e "${YELLOW}:: Limpando cache do pacman...${NC}"
sudo paccache -rk3 2>/dev/null || true

# Verifica integridade dos serviços críticos
echo -e "${YELLOW}:: Verificando status dos serviços...${NC}"
for svc in NetworkManager irqbalance fstrim.timer; do
  if systemctl is-enabled "$svc" &>/dev/null; then
    echo -e "    ${GREEN}✓${NC} $svc ativado"
  else
    echo -e "    ${RED}✗${NC} $svc ${RED}NÃO ativado${NC}"
  fi
done

echo ""
echo -e "${GREEN}:: [5/5] Concluído.${NC}"
echo ""

#------------------------------------------------------------------------------#
#                              FINALIZAÇÃO                                     #
#------------------------------------------------------------------------------#
echo -e "${GREEN}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║   Pós-instalação concluída com sucesso!                  ║"
echo "  ║                                                          ║"
echo "  ║   Próximos passos:                                       ║"
echo "  ║   1. Verifique as alterações e reinicie:                 ║"
echo "  ║        sudo reboot                                       ║"
echo "  ║                                                          ║"
echo "  ║   2. Após reiniciar, execute o script Hyprland ou i3wm:  ║"
echo "  ║        ./install-hyprland.sh                             ║"
echo "  ║        ./install-i3wm.sh                                 ║"
echo "  ║                                                          ║"
echo "  ║   Configurações aplicadas:                               ║"
echo "  ║   ✓ NVIDIA RTX 2060 (nvidia-open-dkms + DRM KMS)         ║"
echo "  ║   ✓ PipeWire + WirePlumber + codecs                      ║"
echo "  ║   ✓ swappiness=10 · vfs_cache_pressure=50                ║"
echo "  ║   ✓ I/O scheduler: none (NVMe)                           ║"
echo "  ║   ✓ irqbalance · fstrim · amd_pstate=active              ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
