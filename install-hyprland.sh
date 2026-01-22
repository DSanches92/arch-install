#!/usr/bin/env bash
#
# Instalação do Hyprland (AMD + NVIDIA Open)
#

set -euo pipefail

#------------------------------------------------------------------------------#
#                            CONFIGURAÇÕES INICIAIS                            #
#------------------------------------------------------------------------------#

GRUB_FILE="/etc/default/grub"
MKINITCPIO_FILE="/etc/mkinitcpio.conf"
GRUB_PARAMS="nvidia-drm.modeset=1 nvidia-drm.fbdev=1"
NVIDIA_MODULES="i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm"

echo " :: Verificando/instalando YAY (AUR Helper)..."
if ! command -v yay &> /dev/null; then
  cd /tmp
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  cd .. && rm -rf yay
else
  echo " :: YAY já instalado. Pulando."
fi

#------------------------------------------------------------------------------#
#                            ATUALIZANDO O SISTEMA                             #
#------------------------------------------------------------------------------#
echo " :: Atualizando sistema..."
yay -Syyuu --noconfirm

#------------------------------------------------------------------------------#
#                          INSTALAÇÃO AUDIO E CODECS                           #
#------------------------------------------------------------------------------#
echo " :: Instalando áudio + codecs..."
sudo pacman -S --needed --noconfirm \
  pipewire pipewire-alsa pipewire-jack pipewire-pulse wireplumber \
  gstreamer gst-libav gst-plugins-base gst-plugins-good gst-plugins-bad \
  gst-plugins-ugly ffmpeg

#------------------------------------------------------------------------------#
#                                NVIDIA DRIVERS                                #
#------------------------------------------------------------------------------#
echo " :: NVIDIA open drivers..."
sudo pacman -S --needed --noconfirm \
  nvidia-open nvidia-utils lib32-nvidia-utils libva-nvidia-driver

echo " :: NVIDIA parâmetros GRUB"
if [[ -f "$GRUB_FILE" ]]; then
  sudo cp "$GRUB_FILE" "$GRUB_FILE.bak-$(date +%Y%m%d-%H%M%S)"
else
  echo " :: Erro: $GRUB_FILE não encontrado!"
  exit 1
fi

CURRENT_LINE=$(sudo grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_FILE" | head -n1)
if [[ -z "$CURRENT_LINE" ]]; then
  echo " :: Linha GRUB_CMDLINE_LINUX_DEFAULT não encontrada. Criando uma básica."
  CURRENT_LINE='GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"'
fi

CURRENT_PARAMS=$(echo "$CURRENT_LINE" | sed -n 's/.*GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)".*/\1/p')
if echo "$CURRENT_PARAMS" | grep -q "$GRUB_PARAMS"; then
  echo " :: Parâmetros '$GRUB_PARAMS' já presente. Pulando."
else
  NEW_PARAMS="$CURRENT_PARAMS $GRUB_PARAMS"
  NEW_PARAMS=$(echo "$NEW_PARAMS" | xargs)

  sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$NEW_PARAMS\"|" "$GRUB_FILE"

  echo " :: Atualizado: GRUB_CMDLINE_LINUX_DEFAULT=\"$NEW_PARAMS\""
fi

sudo grub-mkconfig -o /boot/grub/grub.cfg

echo " :: NVIDIA parâmetros MKINITCPIO"
if [[ -f "$MKINITCPIO_FILE" ]]; then
  sudo cp "$MKINITCPIO_FILE" "$MKINITCPIO_FILE.bak-$(date +%Y%m%d-%H%M%S)"
else
  echo " :: Erro: $MKINITCPIO_FILE não encontrado!"
  exit 1
fi

CURRENT_MODULES_LINE=$(sudo grep "^MODULES=" "$MKINITCPIO_FILE" | head -n1)
if [[ -z "$CURRENT_MODULES_LINE" ]]; then
  echo " :: MODULES não encontrado. Adicionando linha básica."
  sudo sed -i '/^# MODULES=/a MODULES=()' "$MKINITCPIO_FILE"
  CURRENT_MODULES_LINE='MODULES=()'
fi

CURRENT_MODULES=$(echo "$CURRENT_MODULES_LINE" | sed -n 's/.*MODULES=\((.*)\).*/\1/p' | tr -d '()')
for mod in $NVIDIA_MODULES; do
  if ! echo "$CURRENT_MODULES" | grep -qw "$mod"; then
    CURRENT_MODULES="$CURRENT_MODULES $mod"
  fi
done

NEW_MODULES=$(echo "$CURRENT_MODULES" | xargs)
sudo sed -i "s|^MODULES=.*|MODULES=($NEW_MODULES)|" "$MKINITCPIO_FILE"

echo " :: MODULES atualizado: ($NEW_MODULES)"

CURRENT_HOOKS_LINE=$(sudo grep '^HOOKS=' "$MKINITCPIO_FILE" | head -n1)
if [[ -n "$CURRENT_HOOKS_LINE" ]]; then
  CURRENT_HOOKS=$(echo "$CURRENT_HOOKS_LINE" | sed -n 's/.*HOOKS=\((.*)\).*/\1/p' | tr -d '()')

  NEW_HOOKS=$(echo "$CURRENT_HOOKS" | sed 's/kms//g' | xargs)
  if [[ "$NEW_HOOKS" != "$CURRENT_HOOKS" ]]; then
    sudo sed -i "s|^HOOKS=.*|HOOKS=($NEW_HOOKS)|" "$MKINITCPIO_FILE"
    echo " :: Removido 'kms' do HOOKS. Novo: ($NEW_HOOKS)"
  else
    echo " :: Erro: 'kms' não encontrado no HOOKS. Nada alterado."
  fi
else
  echo " :: HOOKS não encontrado. Pulando remoção de kms."
fi

sudo mkinitcpio -P

#------------------------------------------------------------------------------#
#                            HYPRLAND + FERRAMENTAS                            #
#------------------------------------------------------------------------------#
echo " :: Hyprland + ferramentas..."
sudo pacman -S --needed --noconfirm \
  hyprland hyprlock hypridle hyprcursor hyprpaper hyprpicker \
  waybar kitty rofi-wayland yazi qt5-wayland qt6-wayland dunst \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent \
  cliphist ttf-jetbrains-mono-nerd ttf-font-awesome noto-fonts-emoji \
  noto-fonts pavucontrol egl-wayland

sudo yay -S --noconfirm hyprshot wlogout google-chrome

systemctl --user enable pipewire pipewire-pulse wireplumber

echo " :: Desktop instalado! Reinicie ou execute Hyprland manualmente."
sleep 10
shutdown -r now
