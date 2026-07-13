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
if ! sudo -v &>/dev/null; then
  echo " :: ERRO: Este script requer privilégios sudo."
  echo " :: Execute como usuário com permissão sudo (membro do grupo wheel)."
  exit 1
fi

# Mantém o sudo vivo enquanto o script roda
while true; do sudo -v; sleep 60; done &

echo ""
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║       PÓS-INSTALAÇÃO ARCH + BTRFS                        ║"
echo "  ║       Ryzen 5 3600 · RTX 2060 · NVMe · 16GB              ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo ""

#------------------------------------------------------------------------------#
#                   1. SINCRONIZAÇÃO E ATUALIZAÇÃO COMPLETA                    #
#------------------------------------------------------------------------------#
echo " [1/5] Sincronizando repositórios e atualizando o sistema..."
echo ""

paru -Syyuu --noconfirm

echo ""
echo " [1/5] Concluído."
echo ""

#------------------------------------------------------------------------------#
#                   2. DRIVERS NVIDIA (RTX 2060 - TURING)                      #
#------------------------------------------------------------------------------#
echo " [2/5] Instalando drivers NVIDIA (RTX 2060 / Turing)..."
echo ""

# DKMS: compila o módulo aberto (Turing+) contra o linux-zen instalado
sudo pacman -S --needed --noconfirm \
  nvidia-open-dkms \
  nvidia-utils \
  lib32-nvidia-utils \
  nvidia-settings \
  libva-nvidia-driver

echo ""
echo " :: Configurando parâmetros no GRUB..."
echo ""

if [[ -f "$GRUB_FILE" ]]; then
  sudo cp "$GRUB_FILE" "$GRUB_FILE.bak-$(date +%Y%m%d-%H%M%S)"

  CURRENT_LINE=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_FILE" | head -n1)

  if [[ -z "$CURRENT_LINE" ]]; then
    echo " :: ERRO: GRUB_CMDLINE_LINUX_DEFAULT não encontrado."
    exit 1
  fi

  CURRENT_PARAMS=$(echo "$CURRENT_LINE" | sed -n 's/.*GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)".*/\1/p')

  if ! echo "$CURRENT_PARAMS" | grep -q "$GRUB_PARAMS"; then
    NEW_PARAMS="$CURRENT_PARAMS $GRUB_PARAMS"
    NEW_PARAMS=$(echo "$NEW_PARAMS" | xargs)
    sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$NEW_PARAMS\"|" "$GRUB_FILE"
    echo " :: GRUB atualizado: $NEW_PARAMS"
  else
    echo " :: Parâmetros já presentes. Pulando."
  fi
else
  echo " :: ERRO: $GRUB_FILE não encontrado."
  exit 1
fi

echo ""
echo " :: Configurando módulos NVIDIA no mkinitcpio..."
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
  echo " :: MODULES atualizado: ($NEW_MODULES)"

  CURRENT_HOOKS=$(grep "^HOOKS=" "$MKINITCPIO_FILE" | sed -n 's/.*HOOKS=\((.*)\).*/\1/p' | tr -d '()')
  NEW_HOOKS=$(echo "$CURRENT_HOOKS" | sed 's/kms//g' | xargs)
  if [[ "$NEW_HOOKS" != "$CURRENT_HOOKS" ]]; then
    sudo sed -i "s|^HOOKS=.*|HOOKS=($NEW_HOOKS)|" "$MKINITCPIO_FILE"
    echo " :: 'kms' removido dos HOOKS."
  else
    echo " :: 'kms' ausente nos HOOKS. Nada a remover."
  fi
else
  echo " :: ERRO: $MKINITCPIO_FILE não encontrado."
  exit 1
fi

echo ""
echo " :: Reconstruindo initramfs..."
sudo mkinitcpio -P

echo ""
echo " [2/5] Concluído."
echo ""

#------------------------------------------------------------------------------#
#                   3. ÁUDIO (PIPEWIRE + WIREPLUMBER)                         #
#------------------------------------------------------------------------------#
echo " [3/5] Instalando PipeWire, WirePlumber e codecs..."
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
paru -S --needed --noconfirm \
  a52dec \
  faac \
  faad2 \
  flac \
  lame \
  x264 \
  x265 \
  xvidcore

echo ""
echo " :: Ativando serviços de áudio (usuário)..."
systemctl --user enable pipewire pipewire-pulse wireplumber 2>/dev/null || true

echo ""
echo " [3/5] Concluído."
echo ""

#------------------------------------------------------------------------------#
#                   4. OTIMIZAÇÕES DE DESEMPENHO                               #
#------------------------------------------------------------------------------#
echo " [4/5] Aplicando otimizações de desempenho..."
echo ""

# --- Swappiness: reduz uso de swap (16GB RAM, uso apenas emergencial) ---
echo " :: Ajustando swappiness para 10..."
echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-swappiness.conf >/dev/null

# --- Cache de inode/dentry: mantém por mais tempo ---
echo " :: Ajustando vfs_cache_pressure para 50..."
echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.d/99-swappiness.conf >/dev/null

# --- Agendador de E/S: kyber ou none para NVMe ---
echo " :: Configurando agendador de I/O para NVMe..."
for DEV in /sys/block/nvme*/queue/scheduler; do
  if [[ -w "$DEV" ]]; then
    echo "none" | sudo tee "$DEV" >/dev/null
  fi
done

# --- Persiste agendador via udev ---
echo 'ACTION=="add|change", KERNEL=="nvme*", ATTR{queue/scheduler}="none"' | \
  sudo tee /etc/udev/rules.d/60-iosched-nvme.rules >/dev/null

# --- irqbalance: distribui interrupções entre CPUs ---
echo " :: Ativando irqbalance..."
sudo systemctl enable --now irqbalance 2>/dev/null || true

# --- fstrim: já habilitado no instalador base, mas garantimos ---
echo " :: Verificando fstrim.timer..."
sudo systemctl enable --now fstrim.timer 2>/dev/null || true

# --- AMD P-state driver (Ryzen 5 3600) ---
echo " :: Habilitando AMD P-State na linha de comando do kernel..."
if ! grep -q "amd_pstate=active" "$GRUB_FILE" 2>/dev/null; then
  CURRENT_LINE=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_FILE" | head -n1)
  CURRENT_PARAMS=$(echo "$CURRENT_LINE" | sed -n 's/.*GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)".*/\1/p')
  NEW_PARAMS="$CURRENT_PARAMS amd_pstate=active"
  NEW_PARAMS=$(echo "$NEW_PARAMS" | xargs)
  sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$NEW_PARAMS\"|" "$GRUB_FILE"
  echo " :: amd_pstate=active adicionado ao GRUB."
else
  echo " :: amd_pstate=active já presente. Pulando."
fi

sudo grub-mkconfig -o /boot/grub/grub.cfg

echo ""
echo " [4/5] Concluído."
echo ""

#------------------------------------------------------------------------------#
#                   5. LIMPEZA E VERIFICAÇÃO FINAL                             #
#------------------------------------------------------------------------------#
echo " [5/5] Limpeza e verificação final..."
echo ""

# Limpa cache do pacman (mantém apenas as 3 versões mais recentes)
echo " :: Limpando cache do pacman..."
sudo paccache -rk3 2>/dev/null || true

# Verifica integridade dos serviços críticos
echo " :: Verificando status dos serviços..."
for svc in NetworkManager irqbalance fstrim.timer; do
  if systemctl is-enabled "$svc" &>/dev/null; then
    echo "    ✓ $svc ativado"
  else
    echo "    ✗ $svc NÃO ativado"
  fi
done

echo ""
echo " [5/5] Concluído."
echo ""

#------------------------------------------------------------------------------#
#                              FINALIZAÇÃO                                     #
#------------------------------------------------------------------------------#
echo ""
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║   Pós-instalação concluída com sucesso!                  ║"
echo "  ║                                                          ║"
echo "  ║   Próximos passos:                                       ║"
echo "  ║   1. Verifique as alterações e reinicie:                 ║"
echo "  ║        sudo reboot                                       ║"
echo "  ║                                                          ║"
echo "  ║   2. Após reiniciar, execute o script Hyprland:          ║"
echo "  ║        ./install-hyprland.sh                             ║"
echo "  ║                                                          ║"
echo "  ║   Configurações aplicadas:                               ║"
echo "  ║   ✓ NVIDIA RTX 2060 (nvidia-open-dkms + DRM KMS)         ║"
echo "  ║   ✓ PipeWire + WirePlumber + codecs                      ║"
echo "  ║   ✓ swappiness=10 · vfs_cache_pressure=50                ║"
echo "  ║   ✓ I/O scheduler: none (NVMe)                           ║"
echo "  ║   ✓ irqbalance · fstrim · amd_pstate=active              ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo ""
