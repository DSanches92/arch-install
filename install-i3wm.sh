#!/usr/bin/env bash
#
# Script de Instalação do Ambiente Gráfico i3wm
# Customizado para: Danilo (Arch Linux + Zen Kernel)
#
# Terminal: Alacritty | FM: Thunar & Yazi | Barra: Polybar | Launcher: dmenu
#

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║         INSTALAÇÃO DE AMBIENTE GRÁFICO (i3wm)            ║"
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
# 1. INSTALAÇÃO DOS PACOTES DA INTERFACE GRÁFICA
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [1/5] Instalando Xorg + i3wm + utilitários gráficos...${NC}"
paru -S --needed --noconfirm \
    xorg-server xorg-xinit xorg-xauth xorg-xrandr \
    xorg-xset xorg-xprop xorg-xev xclip \
    xf86-input-libinput \
    i3-wm i3blocks i3lock-color i3status  \
    lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings \
    dmenu picom dunst feh xss-lock \
    mate-polkit network-manager-applet \
    bluez bluez-utils blueman

#------------------------------------------------------------------------------#
# 2. INSTALAÇÃO DO TERMINAL, GERENCIADORES DE ARQUIVO E YAZI
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [2/5] Instalando Alacritty, Thunar (e utilitários) e Yazi...${NC}"
paru -S --needed --noconfirm \
    alacritty firefox thunar thunar-volman thunar-archive-plugin \
    thunar-media-tags-plugin gvfs tumbler xdg-user-dirs xdg-utils \
    yazi 7zip unrar unzip jq poppler fd ripgrep fzf zoxide resvg imagemagick ueberzugpp \
    file-roller polybar networkmanager-dmenu-git \
    catppuccin-gtk-theme-macchiato papirus-icon-theme lxappearance \
    btop sxhkd pavucontrol pass xdotool keychain \
    meld pamixer playerctl flameshot greenclip

#------------------------------------------------------------------------------#
# 3. SERVIÇOS DE SISTEMA E DOTFILES
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [3/5] Habilitando serviços do sistema (LightDM e Bluetooth)...${NC}"
sudo systemctl enable lightdm.service
#sudo systemctl set-default graphical.target
sudo systemctl enable --now bluetooth.service

echo -e "${BLUE}:: Clonando configuração i3wm para ~/.config...${NC}"
DOTFILES_TMP="$(mktemp -d)"
git clone https://github.com/DSanches92/my-i3wm.git "$DOTFILES_TMP"
rm -rf "$DOTFILES_TMP/.git"
mkdir -p ~/.config
cp -rT "$DOTFILES_TMP" ~/.config
rm -rf "$DOTFILES_TMP"

echo -e "${YELLOW}:: Aplicando config do greeter...${NC}"
sudo cp -f ~/.config/lightdm/lightdm.conf /etc/lightdm/lightdm.conf
sudo cp -f ~/.config/lightdm/lightdm-gtk-greeter.conf /etc/lightdm/lightdm-gtk-greeter.conf
sudo cp ~/.config/i3/wallpaper_02.png /usr/share/pixmaps/wallpaper_02.png

#------------------------------------------------------------------------------#
# 4. CONFIGURAÇÃO DO ALACRITTY COMO TERMINAL PADRÃO DO SISTEMA
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [4/5] Definindo o Alacritty como terminal padrão...${NC}"
export TERMINAL=alacritty
if ! grep -q '^export TERMINAL=alacritty$' ~/.zshrc 2>/dev/null; then
  echo "export TERMINAL=alacritty" >> ~/.zshrc
fi

#------------------------------------------------------------------------------#
# 5. SETA TECLADO BR ABNT2
#------------------------------------------------------------------------------#
echo -e "${BLUE}:: [5/5] Definindo o Teclado br abnt2...${NC}"
sudo localectl set-x11-keymap br abnt2

echo -e "${GREEN}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║   Instalação gráfica concluída!                          ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${YELLOW}Próximos Passos:${NC}"
echo -e "  1. ${GREEN}sudo reboot${NC}"
echo -e "  2. Login i3 → Super+Enter (Alacritty) | Super+d (dmenu)"
echo -e "  3. Controle de volume já mapeada"
echo -e "  4. Opcional jogos: ${GREEN}./install-gaming.sh${NC}"
echo ""
echo -e "${BLUE}:: REINICIANDO EM 10 SEGUNDOS... ${NC}"
echo ""
sleep 10
reboot
