#!/usr/bin/env bash
#
# Script de Instalação do Ambiente Gráfico Hyprland
# Customizado para: Danilo (Arch Linux + Zen Kernel + RTX 2060)
#
# Terminal: Alacritty | FM: Yazi | Barra: Waybar | Launcher: Rofi (Wayland)
#

set -euo pipefail

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║       INSTALAÇÃO DE AMBIENTE GRÁFICO (Hyprland)          ║"
echo "  ║        Foco em Performance, Estética e Fluidez           ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

#------------------------------------------------------------------------------#
# -- VERIFICAÇÕES INICIAIS
#------------------------------------------------------------------------------#
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}[ERRO] Não execute este script como root/sudo diretamente.${NC}"
    echo "O script precisa rodar com seu usuário comum para que o 'paru' funcione."
    exit 1
fi

if ! command -v paru &> /dev/null; then
    echo -e "${RED}[ERRO] O assistente AUR 'paru' não foi encontrado.${NC}"
    echo "Por favor, garanta que a fase de pós-instalação base foi concluída com sucesso."
    exit 1
fi

#------------------------------------------------------------------------------#
# 1. INSTALAÇÃO DO HYPRLAND + FERRAMENTAS WAYLAND
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [1/6] Instalando Hyprland + ferramentas Wayland...${NC}"
paru -S --needed --noconfirm \
    hyprland hyprlock hypridle hyprcursor hyprpaper hyprpicker \
    waybar alacritty rofi-wayland qt5-wayland qt6-wayland dunst \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent \
    cliphist hyprshot wlogout \
    ttf-jetbrains-mono-nerd ttf-font-awesome noto-fonts \
    pavucontrol egl-wayland

#------------------------------------------------------------------------------#
# 2. NAVEGADOR, GERENCIADOR DE ARQUIVOS (YAZI) E UTILITÁRIOS
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [2/6] Instalando Firefox, Yazi e utilitários...${NC}"
paru -S --needed --noconfirm \
    firefox firefox-i18n-pt-br \
    yazi 7zip jq poppler fd ripgrep fzf zoxide resvg imagemagick

#------------------------------------------------------------------------------#
# 3. BLUETOOTH, KEYRING E APPLET DE REDE
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [3/6] Instalando Bluetooth, keyring e applet de rede...${NC}"
paru -S --needed --noconfirm \
    bluez bluez-utils blueman \
    gnome-keyring libsecret network-manager-applet

#------------------------------------------------------------------------------#
# 4. SERVIÇOS DE SISTEMA (SDDM, BLUETOOTH E FIREWALL)
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [4/6] Instalando e habilitando SDDM (display manager)...${NC}"
paru -S --needed --noconfirm sddm
sudo systemctl enable sddm.service
sudo systemctl set-default graphical.target
sudo systemctl enable --now bluetooth.service

echo -e "${CYAN}:: Ativando firewall...${NC}"
sudo ufw enable
sudo systemctl enable ufw

#------------------------------------------------------------------------------#
# 5. DOTFILES
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [5/6] Clonando configuração Hyprland para ~/.config...${NC}"
DOTFILES_TMP="$(mktemp -d)"
git clone https://github.com/DSanches92/my-hyprland.git "$DOTFILES_TMP"
rm -rf "$DOTFILES_TMP/.git"
mkdir -p ~/.config
cp -rT "$DOTFILES_TMP" ~/.config
rm -rf "$DOTFILES_TMP"

# Nota: diferente do X11 (localectl set-x11-keymap), o layout de teclado no
# Hyprland/Wayland é definido dentro do hyprland.conf (bloco "input { kb_layout = br }"),
# que vem do repositório de dotfiles acima — não faz sentido setar via localectl aqui.

#------------------------------------------------------------------------------#
# 6. CONFIGURAÇÃO DO ALACRITTY COMO TERMINAL PADRÃO DO SISTEMA
#------------------------------------------------------------------------------#
echo -e "${CYAN}:: [6/6] Definindo o Alacritty como terminal padrão...${NC}"
export TERMINAL=alacritty
if ! grep -q '^export TERMINAL=alacritty$' ~/.zshrc 2>/dev/null; then
  echo "export TERMINAL=alacritty" >> ~/.zshrc
fi

echo -e "${GREEN}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║   Instalação gráfica concluída!                          ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${YELLOW}Próximos Passos:${NC}"
echo -e "  1. ${GREEN}sudo reboot${NC}"
echo -e "  2. Login via SDDM → sessão Hyprland"
echo -e "  3. Opcional jogos: ${GREEN}./install-gaming.sh${NC}"
echo ""
echo -e "${CYAN}:: REINICIANDO EM 10 SEGUNDOS... ${NC}"
echo ""
sleep 10
reboot
